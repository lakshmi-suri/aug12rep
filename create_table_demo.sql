create or replace database newgitdb;

--set context 
use warehouse instructor1_wh;
use database newgitdb;
use schema newgitdb.public;
--this line is modefied

--create table and load data

create or replace table mytab (id int);
insert into mytab values (100);
