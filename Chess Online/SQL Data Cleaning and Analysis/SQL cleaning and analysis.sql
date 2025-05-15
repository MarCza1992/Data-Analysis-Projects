-- creating a back up table in case we mess something up

create table chess_backup_table
like chess;

insert into chess_backup_table
select *
from chess;

						            -- CLEANING DATA --

-- changing messed up id column name

alter table chess change ď»żgame_id game_id int; 

-- deleting duplicates

with table1 as
(
select *,
row_number() over(partition by rated, victory_status, winner, time_increment, white_id, white_rating, black_id, black_rating, moves, opening_moves, opening_shortname) as rn
from chess
)
select *
from table1
where rn > 1; -- checking duplicates

CREATE TABLE `chess2` (
  `game_id` int DEFAULT NULL,
  `rated` text,
  `turns` int DEFAULT NULL,
  `victory_status` text,
  `winner` text,
  `time_increment` text,
  `white_id` text,
  `white_rating` int DEFAULT NULL,
  `black_id` text,
  `black_rating` int DEFAULT NULL,
  `moves` text,
  `opening_code` text,
  `opening_moves` int DEFAULT NULL,
  `opening_fullname` text,
  `opening_shortname` text,
  `opening_response` text,
  `opening_variation` text,
  `rn` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

insert into chess2
select *,
row_number() over(partition by rated, victory_status, winner, time_increment, white_id, white_rating, black_id, black_rating, moves, opening_code, opening_moves, opening_fullname, opening_shortname, opening_response, opening_variation) as rn
from chess
order by game_id;

delete
from chess2
where rn > 1;

DROP TABLE chess;
RENAME TABLE chess2 TO chess;
alter table chess drop column rn;

-- transforming 'moves' column into a 'first_move' column, will be more useful for analysis

update chess
set moves = CASE 
	WHEN locate(' ', moves) > 0 THEN substr(moves, 1, locate(' ', moves) - 1)
    ELSE moves
END;

alter table chess change moves first_move text;

-- deleting opening columns I won't use (opening shortname is the most important one)
alter table chess
drop column opening_code,
drop column opening_fullname,
drop column opening_response,
drop column opening_variation; 



							-- SOME INTERESTING QUERIES TO ANSWER SOME QUESTIONS FOR DATA ANALYSIS

-- ranked vs unranked games percentage

with table1 as
(
select rated, count(game_id) as games, sum(count(game_id)) over() as total_games
from chess
group by rated
)
select rated, concat(round((games / total_games) * 100, 2), '%') as Percentage_of_games
from table1; -- ~80% games are ranked games

-- percentage breakdown of all win types depending on whether the game was won by White, Black, or ended in a draw.

with table1 as
(
select winner, victory_status, count(game_id) as games, sum(count(game_id)) over() as total_games
from chess
group by winner, victory_status
order by winner desc, games desc
)
select winner, victory_status,
concat(round((games / total_games) * 100, 2), '%') as Percentage_of_games
from table1; -- White wins more often than Black (by around 5%), and resignation is by far the most common way of winning. We can also observe that Black wins slightly more often than White by time out.

-- top 100 players based on their peak rating

with table1 as
(
select game_id, white_id as player_id, white_rating as player_rating
from chess
UNION ALL
select game_id, black_id as player_id, black_rating as player_rating
from chess
), table2 as
(
select player_id, max(player_rating) as peak_rating
from table1
group by player_id
)
select rank() over(order by peak_rating desc) as `rank`, player_id, peak_rating
from table2
limit 100;

-- game length (in terms of number of moves) presented as a percentage based on defined intervals

with table1 as
(
select 
CASE
	WHEN turns between 1 and 10 THEN 'Express (1-10 turns)'
    WHEN turns between 11 and 30 THEN 'Short (11-30 turns)'
    WHEN turns between 31 and 60 THEN 'Standard (31-60 turns)'
    WHEN turns between 61 and 100 THEN 'Long (61-100 turns)'
    ELSE 'Very long (100+ turns)'
END as Duration_of_game_by_turns,
count(game_id) as games,
sum(count(game_id)) over() as total_games
from chess
group by Duration_of_game_by_turns
order by games desc
)
select Duration_of_game_by_turns,
concat(round((games / total_games) * 100, 2), '%') as Percentage_of_games
from table1; -- almost 70% of the games ends in 31-100 turns, there are very rare cases (3,31%) when games ends in few moves

-- top 2 played openings for every first move

with table1 as
(
select first_move, 
opening_shortname, 
count(game_id) as games
from chess
group by first_move, opening_shortname
), table2 as
(
select
rank() over(partition by first_move order by games desc) as ranking,
first_move,
opening_shortname,
games
from table1
)
select first_move, opening_shortname, games
from table2
where ranking <= 2;

-- How often did lower-rated players win their games (in percentage terms)?

with table1 as
(
select
CASE
	WHEN white_rating > black_rating AND winner = 'black' THEN 'yes (as black)'
    WHEN black_rating > white_rating AND winner = 'white' THEN 'yes (as white)'
    WHEN white_rating > black_rating AND winner = 'draw' THEN 'draw (as black)'
    WHEN black_rating > white_rating AND winner = 'draw' THEN 'draw (as white)'
    ELSE 'no'
END Did_weaker_player_won,
count(game_id) as games, 
sum(count(game_id)) over() as total_games
from chess
group by Did_weaker_player_won
order by games desc
)
select Did_weaker_player_won,
concat(round((games / total_games) * 100, 2), '%') as Percentage_of_games
from table1
where Did_weaker_player_won IN ('yes (as black)', 'yes (as white)', 'draw (as black)', 'draw (as white)'); -- weaker players wins around 33% of games nad around 4,5% ends with a draw. They are winning or drawing slightly more often as a white

-- all openings in which Black has a higher win rate than White, based on a sample of at least 50 games (excluding draws)

with table1 as
(
select
opening_shortname,
winner,
count(game_id) as games,
sum(count(game_id)) over(partition by opening_shortname) as total_games
from chess
where winner != 'draw'
group by opening_shortname, winner
order by opening_shortname, games desc
), table2 as
(
select opening_shortname,
concat(round((games / total_games) * 100, 2), '%') as 'Percentage of wins as black (excluding draws)',
round((games / total_games) * 100, 2) as black_efficiency
from table1
where total_games >= 50 AND winner = 'black'
)
select opening_shortname, `Percentage of wins as black (excluding draws)`
from table2
where black_efficiency > 50.00
order by black_efficiency desc; -- Van't Kruijs Opening opening seems to be the most efficient opening against White as a Black with a 64.22% winrate, overall we have 16 opening where Black wins more often than White

-- players with the highest win rate who have played at least 30 ranked games

with table1 as
(
select 
white_id as player_id,
CASE
	WHEN winner = 'white' THEN 'win'
    WHEN winner = 'black' THEN 'lose'
    ELSE 'draw'
END as game_result
from chess
where rated = 'TRUE'
UNION ALL
select 
black_id as player_id,
CASE
	WHEN winner = 'white' THEN 'lose'
    WHEN winner = 'black' THEN 'win'
    ELSE 'draw'
END as game_result
from chess
where rated = 'TRUE'
), table2 as
(
select player_id, game_result,
count(*) as games,
sum(count(*)) over(partition by player_id) as total_games
from table1
group by player_id, game_result
order by player_id, games desc
), table3 as
(
select player_id,
round((games / total_games) * 100, 2) as efficiency,
concat(round((games / total_games) * 100, 2), '%') as 'Percentage of wins',
total_games as total_games_played
from table2
where total_games >= 30 AND game_result = 'win'
order by efficiency desc
)
select player_id, `Percentage of wins`, total_games_played
from table3;

-- openings with the longest book move sequences, based on at least 50 games

select opening_shortname, avg(opening_moves) as avarage_number_of_opening_moves, max(opening_moves) as max_number_of_moves, min(opening_moves) as min_number_of_moves, count(game_id) as total_games_played
from chess
group by opening_shortname
having total_games_played >= 50
order by 2 desc; -- Gruenfeld Defense, King''s Indian Defense and Semi-Slav Defense are the openings with the longest book move sequences by avarage


