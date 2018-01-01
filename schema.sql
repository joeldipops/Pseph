-- Destroy all connections (Extremely satifying)
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE datname = 'Pseph'
  AND pid <> pg_backend_pid();

DO
$$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_user
        WHERE usename = 'pseph'
    )
    THEN
        DROP OWNED BY pseph;
    END IF;
END
$$;

DROP DATABASE IF EXISTS pseph;
DROP ROLE IF EXISTS pseph;

CREATE ROLE pseph
    WITH LOGIN
    PASSWORD '_';

CREATE DATABASE pseph
    WITH OWNER pseph;

-- Has to be lowercase for some reason.
\c pseph

ALTER DEFAULT PRIVILEGES
    IN SCHEMA public
    GRANT ALL ON TABLES
    TO pseph;
ALTER DEFAULT PRIVILEGES
    IN SCHEMA public
    GRANT ALL ON SEQUENCES
    TO pseph;
ALTER DEFAULT PRIVILEGES
    IN SCHEMA public
    GRANT ALL ON FUNCTIONS
    TO pseph;

-- Required for Pivot functions
CREATE EXTENSION tablefunc;

CREATE TABLE Preference (
    PreferenceId serial NOT NULL,
    PaperId int NOT NULL,
    CandidateId int NOT NULL,
    PreferenceNumber smallint NOT NULL
        DEFAULT 1,
    
    CONSTRAINT PK_Preference PRIMARY KEY (PreferenceId)
); 

CREATE UNIQUE INDEX LK_Preference
ON Preference (PaperId, CandidateId);

CREATE VIEW vBallotPaper 
AS
    SELECT *
    FROM crossTab('
        SELECT PaperId, CandidateId, PreferenceNumber
        FROM Preference
    ', '
        SELECT i
        FROM generate_series(1, 4) AS pos(i)
        ORDER BY i
    ') AS r(PaperId int, Candidate1 int, Candidate2 int, Candidate3 int, Candidate4 int)
;

CREATE TABLE Weight (
    PreferenceNumber int NOT NULL,
    Weight numeric(3, 2) NOT NULL
);

CREATE VIEW vExplicitlyWeighted
AS
    SELECT 
        P.CandidateId,
        sum(W.Weight) AS WeightedVotes
    FROM Preference P
        INNER JOIN Weight W
        ON W.PreferenceNumber = P.PreferenceNumber
    GROUP BY P.CandidateId
    ORDER BY sum(W.Weight) DESC
;
    
CREATE FUNCTION fnImplicitlyWeighted(
    Factor decimal
)
    RETURNS TABLE (
        CandidateId int,
        WeightedVotes decimal,
        PrimaryVotes decimal
    )
AS
$BODY$
BEGIN
    RETURN QUERY
        SELECT 
            P.CandidateId,
            cast(
                CASE WHEN max(L.max) <> 1
                    THEN
                        sum(
                            (-1/(
                                (L.max - 1) ^ Factor
                            )) * 
                            ((P.PreferenceNumber-1)^Factor) 
                            + 1
                        )                    
                    ELSE sum(P.PreferenceNumber)
                END
            AS decimal(6, 3)),
            coalesce(sum(O.Primary), 0)
        FROM Preference P
            CROSS JOIN (
                SELECT max(PreferenceNumber) AS max
                FROM Preference
            ) L
            
            -- Break ties with primary vote.
            LEFT JOIN LATERAL (
                SELECT count(1) AS Primary
                FROM Preference O
                WHERE 
                    O.PreferenceId = P.PreferenceId
                    AND O.PreferenceNumber = 1
                GROUP BY O.CandidateId
            ) O ON TRUE
        GROUP BY P.CandidateId
        ORDER BY 
            CASE WHEN max(L.max) <> 1 
                THEN
                    sum(
                        (-1/(
                            (L.max - 1) ^ Factor
                        )) * 
                        ((P.PreferenceNumber-1)^Factor) 
                        + 1
                    )                    
                ELSE sum(P.PreferenceNumber)
            END DESC,
            coalesce(sum(O.Primary), 0) DESC
        ;
END;
$BODY$ LANGUAGE plpgsql;  



