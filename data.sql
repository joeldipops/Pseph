\c pseph
TRUNCATE TABLE Preference;
INSERT INTO Preference (PaperId, CandidateId, PreferenceNumber)
VALUES
    (1, 1, 1),
    (1, 2, 1),
    
    (2, 1, 2),
    (2, 2, 1),
    
    (3, 4, 1),
    (3, 3, 2),
    (3, 2, 3),
    (3, 1, 4),
    
    (4, 3, 1),
    
    (5, 3, 2),
    (5, 4, 1),
    (5, 1, 3),
    (5, 2, 4),
    
    (6, 2, 1)
;
    
TRUNCATE TABLE Weight;
INSERT INTO Weight (PreferenceNumber, Weight)
VALUES
    (1, 1),
    (2, 0.5),
    (3, 0.33),
    (4, 0.25),
    (5, 0.2)
;    
