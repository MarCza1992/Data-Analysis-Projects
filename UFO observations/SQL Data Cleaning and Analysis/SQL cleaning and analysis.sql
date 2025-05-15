-- creating a back up table in case we mess something up

create table ufo_backup_table
like ufo;

insert into ufo_backup_table
select *
from ufo;

						            -- CLEANING DATA --

-- Changing 'datetime' column name to 'date_reported' and duration columns

alter table ufo change `datetime` date_reported datetime;
alter table ufo change `duration (seconds)` duration_seconds bigint;
alter table ufo change `duration (hours/min)` duration_text_time text;

-- removing duplicated data (by date, latitude and longitude columns)

with table1 as
(
select *,
row_number() over (partition by date_reported, latitude, longitude) as rn
from ufo
)
select *
from table1
where rn > 1; -- checking duplicates (over 1000 rows)

CREATE TABLE `ufo2` (
  `date_reported` datetime DEFAULT NULL,
  `city` text,
  `state` text,
  `country` text,
  `shape` text,
  `duration_seconds` bigint DEFAULT NULL,
  `duration_text_time` text,
  `comments` text,
  `date posted` text,
  `latitude` text,
  `longitude` text,
  `rn` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci; -- creating new table to delete duplicates

insert into ufo2
select *,
row_number() over (partition by date_reported, latitude, longitude) as rn
from ufo; -- filling new table with data

delete
from ufo2
where rn > 1; -- delete duplicates

DROP TABLE ufo;
RENAME TABLE ufo2 TO ufo;
alter table ufo drop column rn; -- updating orginal ufo table and removing 'rn' column, we dont need it anymore

-- changing state and country to uppercases (looks better)
update ufo
set state = upper(state);
update ufo
set country = upper(country);

-- changing blank values in 'shape' column with 'unknown' values

update ufo
set shape = 'unknown'
where shape = '';

-- will focus only on data that observation time (duration time in seconds) is no longer than 1 hour, because most of the data above that time seems to be useless

delete
from ufo
where duration_seconds > 3600;

-- deleting columns we dont need

alter table ufo drop column duration_text_time;
alter table ufo drop column `date posted`;
alter table ufo drop column comments;

-- adding the most important country codes to blank ones in rows where we can define from city column in which country ufo was noticed

UPDATE ufo
SET country = CASE
    WHEN city LIKE '%(United States)%' THEN 'US'
    WHEN city LIKE '%(United Kingdom)%' THEN 'GB'
    WHEN city LIKE '%(uk/england)%' THEN 'GB'
    WHEN city LIKE '%(uk/scotland)%' THEN 'GB'
    WHEN city LIKE '%(uk/wales)%' THEN 'GB'
    WHEN city LIKE '%(Germany)%' THEN 'DE'
    WHEN city LIKE '%(France)%' THEN 'FR'
    WHEN city LIKE '%(Spain)%' THEN 'ES'
    WHEN city LIKE '%(Italy)%' THEN 'IT'
    WHEN city LIKE '%(Canada)%' THEN 'CA'
    WHEN city LIKE '%(Australia)%' THEN 'AU'
    WHEN city LIKE '%(Mexico)%' THEN 'MX'
    WHEN city LIKE '%(Brazil)%' THEN 'BR'
    WHEN city LIKE '%(Poland)%' THEN 'PL'
    WHEN city LIKE '%(Netherlands)%' THEN 'NL'
    WHEN city LIKE '%(Belgium)%' THEN 'BE'
    WHEN city LIKE '%(Sweden)%' THEN 'SE'
    WHEN city LIKE '%(Norway)%' THEN 'NO'
    WHEN city LIKE '%(Denmark)%' THEN 'DK'
    WHEN city LIKE '%(Finland)%' THEN 'FI'
    WHEN city LIKE '%(Ireland)%' THEN 'IE'
    WHEN city LIKE '%(Switzerland)%' THEN 'CH'
    WHEN city LIKE '%(Austria)%' THEN 'AT'
    WHEN city LIKE '%(New Zealand)%' THEN 'NZ'
    WHEN city LIKE '%(Russia)%' THEN 'RU'
    WHEN city LIKE '%(Japan)%' THEN 'JP'
    WHEN city LIKE '%(China)%' THEN 'CN'
    WHEN city LIKE '%(South Korea)%' THEN 'KR'
    WHEN city LIKE '%(India)%' THEN 'IN'
    WHEN city LIKE '%(South Africa)%' THEN 'ZA'
    WHEN city LIKE '%(Argentina)%' THEN 'AR'
    WHEN city LIKE '%(Chile)%' THEN 'CL'
    WHEN city LIKE '%(Colombia)%' THEN 'CO'
    WHEN city LIKE '%(Portugal)%' THEN 'PT'
    WHEN city LIKE '%(Czech Republic)%' THEN 'CZ'
    WHEN city LIKE '%(Hungary)%' THEN 'HU'
    WHEN city LIKE '%(Greece)%' THEN 'GR'
    WHEN city LIKE '%(Turkey)%' THEN 'TR'
    WHEN city LIKE '%(Ukraine)%' THEN 'UA'
    ELSE country
END
WHERE country = '';

-- same as above but using state names when country is blank

UPDATE ufo
SET country = CASE
    WHEN state IN ('AK','AL','AR','AZ','CA','CO','CT','DC','DE','FL',
                   'GA','HI','IA','ID','IL','IN','KS','KY','LA','MA',
                   'MD','ME','MI','MN','MO','MS','MT','NC','ND','NE',
                   'NH','NJ','NM','NV','NY','OH','OK','OR','PA','PR', 
                   'RI','SC','SD','TN','TX','UT','VA','VT','WA','WI',
                   'WV','WY') THEN 'US'
    WHEN state IN ('AB','BC','MB','NB','NL','NS','NT','ON','PE','QC','SK','YT','YK','PQ','NF') THEN 'CA'
    WHEN state = 'SA' THEN 'AU'
    ELSE country
END
WHERE country = '';

-- deleting rows where country is unknown, we dont need these rows for analysis

delete
from ufo
where country = '';

-- adding unique id for every row

alter table ufo add column case_id int auto_increment primary key first;

							-- SOME INTERESTING QUERIES TO ANSWER SOME QUESTIONS FOR DATA ANALYSIS

-- what kind of UFO shapes are the most often observed?

select shape, count(case_id) as 'Number of cases'
from ufo
group by shape
order by 2 desc; -- if we do not count "light" as a shape then definitely the most often observed shapes are triangles and circles

-- Which US states report the most UFO sightings?

select country, state, count(case_id) as 'Number of cases'
from ufo
where country = 'US'
group by country, state
order by 3 desc; -- California has the highest number of reported UFO sightings — twice as many as the second-highest state. Other states with a significant number of sightings are Florida, Washington, Texas and New York

-- How have the yearly trends in UFO sightings developed since the year 1990?

select year(date_reported) as 'year', count(case_id) as 'Number of cases'	
from ufo
where year(date_reported) >= 1990
group by year(date_reported)
order by 1; -- we can see that the trend in reported sightings has been consistently increasing since 1990

-- How long was the UFO observed?

select 
CASE
	WHEN duration_seconds between 1 and 59 THEN 'Very short (0-1 minutes)'
    WHEN duration_seconds between 60 and 179 THEN 'Short (1-3 minutes)'
    WHEN duration_seconds between 180 and 299 THEN 'Medium (3-5 minutes)'
    WHEN duration_seconds between 300 and 899 THEN 'Long (5-15 minutes)'
    ELSE 'Very Long (15-60min)'
END as 'Duration of observation',
count(case_id) as 'Number of cases'
from ufo
group by `Duration of observation`
order by CASE `Duration of observation`
	WHEN 'Very short (0-1 minutes)' THEN 1
    WHEN 'Short (1-3 minutes)' THEN 2
    WHEN 'Medium (3-5 minutes)' THEN 3
    WHEN 'Long (5-15 minutes)' THEN 4
    ELSE 5
END; -- Most sightings are very short (under 1 minute), but there are also many cases where the UFO was observed for 5 minutes or longer

-- Are the statistics different in other countries if we exclude the US, Canada, and Mexico?

select shape, count(case_id) as 'Number of cases'
from ufo
where country not in ('US', 'CA', 'MX')
group by shape
order by 2 desc; -- in terms of UFO shape, statistics are very similar

select year(date_reported) as 'year', count(case_id) as 'Number of cases'	
from ufo
where year(date_reported) >= 1990 and country not in ('US', 'CA', 'MX')
group by year(date_reported)
order by 1; -- in terms of yearly trends in UFO sightings, we can notice that number of reported cases between 2001-2009 was pretty stable and started decreasing since 2010

select 
CASE
	WHEN duration_seconds between 1 and 59 THEN 'Very short (0-1 minutes)'
    WHEN duration_seconds between 60 and 119 THEN 'Short (1-3 minutes)'
    WHEN duration_seconds between 120 and 299 THEN 'Medium (3-5 minutes)'
    WHEN duration_seconds between 300 and 899 THEN 'Long (5-15 minutes)'
    ELSE 'Very Long (15-60min)'
END as 'Duration of observation',
count(case_id) as 'Number of cases'
from ufo
where country not in ('US', 'CA', 'MX')
group by `Duration of observation`
order by CASE `Duration of observation`
	WHEN 'Very short (0-1 minutes)' THEN 1
    WHEN 'Short (1-3 minutes)' THEN 2
    WHEN 'Medium (3-5 minutes)' THEN 3
    WHEN 'Long (5-15 minutes)' THEN 4
    ELSE 5
END; -- in terms of duration of the UFO sighting, statistics are very similar



