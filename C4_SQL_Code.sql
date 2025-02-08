CREATE DATABASE C4Interview;

-- Deleting duplicate Video_id in Video_Meta_Data
WITH DuplicateRows AS (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY Video_ID ORDER BY (SELECT NULL)) AS RowNum
    FROM Video_Meta_Data
)
DELETE FROM Video_Meta_Data
WHERE Video_ID IN (
    SELECT Video_ID FROM DuplicateRows WHERE RowNum > 1
);

-- Assigning Unique Video_Id to the Youtube_Viewing_Data
WITH CTE AS (
    SELECT Video_ID, 
           ROW_NUMBER() OVER (PARTITION BY Video_ID ORDER BY (SELECT NULL)) AS RowNum
    FROM YouTube_Viewing_Data
)
UPDATE Y
SET Video_ID = Y.Video_ID + C.RowNum
FROM YouTube_Viewing_Data Y
INNER JOIN CTE C
ON Y.Video_ID = C.Video_ID
WHERE C.RowNum > 1;

-- Removing null values on Date_of_View in Youtube_Viewing_Data
DELETE FROM YouTube_Viewing_Data WHERE Date_of_View IS NULL;

-- Removing null values on Series in Video_Meta_Data
DELETE FROM Video_Meta_Data WHERE Series IS NULL;

-- Assigning the rows to not null
ALTER TABLE YouTube_Viewing_Data 
ALTER COLUMN Video_ID INT NOT NULL;

ALTER TABLE YouTube_Viewing_Data 
ALTER COLUMN Date_of_View DATE NOT NULL;

-- Adding primary key to Video_Meta_Data
ALTER TABLE Video_Meta_Data ADD CONSTRAINT PK_VideoMeta PRIMARY KEY (Video_ID);

-- Adding primary key to YouTube_Viewing_Data
ALTER TABLE YouTube_Viewing_Data ADD CONSTRAINT PK_YTViews PRIMARY KEY (Video_ID, Date_of_View);

-- Removing orphaned rows
DELETE FROM YouTube_Viewing_Data
WHERE Video_ID NOT IN (SELECT Video_ID FROM Video_Meta_Data);

-- Linking YouTube_Viewing__Data to Video_Meta_Data using Video_ID
ALTER TABLE YouTube_Viewing_Data 
ADD CONSTRAINT FK_YTViews_Video_Meta 
FOREIGN KEY (Video_ID) REFERENCES Video_Meta_Data(Video_ID);

-- QUESTION 1: Write a SQL query that returns a list of videos where 50% or more of their total views in 2024 are from 13-34 year olds.
SELECT v.Video_ID, v.Video_Title
FROM YouTube_Viewing_Data y
JOIN Video_Meta_Data v ON y.Video_ID = v.Video_ID
WHERE YEAR(y.Date_of_View) = 2024
GROUP BY v.Video_ID, v.Video_Title
HAVING SUM(y._13_34_Year_Old_Views) * 2 >= SUM(y.YouTube_Views);

-- QUESTION 2: Write a SQL query that returns a running sum of views by series, aggregated by month.
SELECT  
    v.Series,  
    FORMAT(MIN(y.Date_of_View), 'MMMM yyyy') AS Month,  
    SUM(y.YouTube_Views) AS Monthly_Views,  
    SUM(SUM(y.YouTube_Views)) OVER (PARTITION BY v.Series ORDER BY YEAR(MIN(y.Date_of_View)), MONTH(MIN(y.Date_of_View))) AS Running_Total_Views  
FROM YouTube_Viewing_Data y  
JOIN Video_Meta_Data v ON y.Video_ID = v.Video_ID    
GROUP BY v.Series, YEAR(y.Date_of_View), MONTH(y.Date_of_View)  
ORDER BY v.Series, YEAR(MIN(y.Date_of_View)), MONTH(MIN(y.Date_of_View));

-- QUESTION 3: Write a SQL query that allows you to compare the current weeks views, to the previous weeks views for a given content format
WITH WeeklyViews AS (
    SELECT v.Content_Format, DATEPART(WEEK, y.Date_of_View) AS Week, 
           SUM(y.YouTube_Views) AS Views
    FROM YouTube_Viewing_Data y
    JOIN Video_Meta_Data v ON y.Video_ID = v.Video_ID
    WHERE v.Content_Format IS NOT NULL
    GROUP BY v.Content_Format, DATEPART(WEEK, y.Date_of_View)
)
SELECT w1.Content_Format, w1.Week, w1.Views AS Current_Week_Views, 
       COALESCE(w2.Views, 0) AS Previous_Week_Views,
       w1.Views - COALESCE(w2.Views, 0) AS View_Change
FROM WeeklyViews w1
LEFT JOIN WeeklyViews w2 
ON w1.Content_Format = w2.Content_Format AND w1.Week = w2.Week + 1
ORDER BY w1.Content_Format, w1.Week;
