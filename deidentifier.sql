# Switch to this database
USE openmrs;
SET FOREIGN_KEY_CHECKS=0;
SET SQL_SAFE_UPDATES = 0;
SET @@local.net_read_timeout=360;

-- these tables will not be used, so drop their contents 
-- TODO add muzima and non-openmrs core tables
truncate table concept_proposal;
truncate table hl7_in_archive;
truncate table hl7_in_error;
truncate table hl7_in_queue;
truncate table formentry_error;
truncate table user_property;
truncate table notification_alert_recipient;
truncate table notification_alert;


-- dummy values are entered into these tables later
truncate table patient_identifier;
truncate table patient_identifier_type;

-- clear out the username/password stored in the db
update global_property set property_value = 'admin' where property like '%.username';
update global_property set property_value = 'test' where property like '%.password';

--
-- randomize the person names in the database
-- 
drop table if exists random_names;

CREATE TABLE `random_names` (
	`rid` int(11) NOT NULL auto_increment,
	`name` varchar(255) NOT NULL,
	PRIMARY KEY  (`rid`),
	UNIQUE KEY `name` (`name`),
	UNIQUE KEY `rid` (`rid`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

-- make the randome names table hold all unique first
insert into random_names (name, rid) select distinct(trim(given_name)) as name, null from person_name where given_name is not null and not exists (select * from random_names where name = trim(given_name));
-- uncomment to include middle and first name
# insert into random_names (name, rid) select distinct(trim(middle_name)) as name, null from person_name where middle_name is not null and not exists (select * from random_names where name = trim(middle_name));
# insert into random_names (name, rid) select distinct(trim(family_name)) as name, null from person_name where family_name is not null and not exists (select * from random_names where name = trim(family_name));

drop procedure if exists randomize_names;
delimiter //
create procedure randomize_names()
begin
	set @size = (select max(person_name_id) from person_name);
	set @start = 0;
	-- if stepsize is increased, you should increase "limit 300" below as well
	set @stepsize = 300; 
	while @start < @size do
		update
			person_name
		set
			given_name = (select
									name
								from
									(select
										rid
										from
										random_names
										order by
										rand()
										limit 300
									) rid,
									random_names rn
								where	
									rid.rid = rn.rid
								order by
									rand()
								limit 1
							),
						middle_name = given_name,
						family_name = middle_name
		where
			person_name_id between @start and (@start + @stepsize);
		
		set @start = @start + @stepsize +1;
	end while;
end;
//
delimiter ;
call randomize_names();
drop procedure if exists randomize_names;

--
-- Randomize the birth dates and months (leave years the same)
--

-- this query randomizes the month, then the day as opposed to the later ones that just randomizes on month*days
-- update person set birthdate = date_add(date_add(birthdate, interval cast(rand()*12-12 as signed) month),interval cast(rand()*30-30 as signed) day) where birthdate is not null;

-- randomize +/- 6 months for persons older than ~15 yrs old
update person set birthdate = date_add(birthdate, interval cast(rand()*182-182 as signed) day) where birthdate is not null and datediff(now(), birthdate) > 15*365;

-- randomize +/- 3 months for persons between 15 and 5 years old
update person set birthdate = date_add(birthdate, interval cast(rand()*91-91 as signed) day) where birthdate is not null and datediff(now(), birthdate) between 15*365 and 5*365;

-- randomize +/- 30 days for persons less than ~5 years old
update person set birthdate = date_add(birthdate, interval cast(rand()*30-30 as signed) day) where birthdate is not null and datediff(now(), birthdate) < 5*365;

update person set birthdate_estimated = cast(rand() as signed);

-- randomize the death date +/- 3 months
update 
	person
set
	death_date = date_add(death_date, interval cast(rand()*91-91 as signed) day)
where 
	death_date is not null;

--
-- Randomize the encounter and obs dates
-- shifted all encounters in the future so that it doesn't conflict with birth/death dates
-- Sequence of events has been preserved
--
		
-- change all encounter_datetime values to the random value (preserve sequence of events)
-- to presever the squence of events, I'm using a dynamic seed generated based on week and yrs

update 
  encounter e
set 
	e.encounter_datetime = adddate(encounter_datetime, 91+RAND(week(encounter_datetime)*year(encounter_datetime))*3),
	e.date_created = adddate(date_created, 91+RAND(week(date_created)*year(date_created))*3);
	

-- randomize all obs
-- change all obs_datetime values to the random value (preserve sequence of events)
update
	obs o
set
	o.obs_datetime = adddate(obs_datetime, 91+RAND(week(obs_datetime)*year(obs_datetime))*3),
    o.value_text = null, # text might contain identifiable info
	o.date_created = adddate(date_created, 91+RAND(week(date_created)*year(date_created))*3);


--
-- Randomize the transfer location dates 
-- 
set @health_center_id = (select person_attribute_type_id from person_attribute_type where name = 'Health Center');
update 
	person_attribute
set
	date_created = date_add(date_created, interval cast(rand()*91-91 as signed) day)
where
	person_attribute_type_id = @health_center_id;

set @race_id = (select person_attribute_type_id from person_attribute_type where name = 'Race');
delete from
	person_attribute
where
	person_attribute_type_id = @race_id;

set @birthplace_id = (select person_attribute_type_id from person_attribute_type where name = 'Birthplace');
delete from
	person_attribute
where
	person_attribute_type_id = @birthplace_id;

--
-- Rename location to something nonsensical
--
update
	location
set
	name = concat('Location-', location_id);
	
-- 
-- Dumb-ify the identifiers
-- (assumes patient_identifier_type and patient_identifier
-- have been truncated
-- 
insert into
	patient_identifier_type
	(uuid,name, description, check_digit, creator, date_created, required, retired)
values
	('32876eca-f64b-4006-82b5-74c2e8f1730c','Dummy Identifier', '', 0, 1, '20080101', 0, 0);

insert into 
	patient_identifier
	(uuid,patient_id, identifier, identifier_type, location_id, preferred, creator, date_created, voided)
select
    MD5(rand()),
	patient_id,
	concat('ident-', patient_id),
	1,
	1,
	1,
	1,
	'20080101',
	0
from
	patient;

	
-- 
-- Dumbify the usernames and clear out login info
--
update
	users
set
	username = concat('username-', user_id);

update users set password = '4a1750c8607dfa237de36c6305715c223415189';
update users set salt = 'c788c6ad82a157b712392ca695dfcf2eed193d7f';
update users set secret_question = null;
update users set secret_answer = null;

--
-- Shift the person addresses around
--
update 
	person_address
set
	address1 = concat(person_id, ' address1'),
	address2 = concat(person_id, ' address2'),
	latitude = null,
	longitude = null,
	`city_village` = concat(person_id, ' city_village'),
	`state_province` = concat(person_id, ' state_province'),
	`postal_code` = concat(person_id, ' postal_code'),
	`county_district` = concat(person_id, ' county_district'),
	`address3` = concat(person_id, ' XXXX3'),
	`address4` =concat(person_id, ' XXXX4'),
	`address5` =concat(person_id, ' XXXX5'),
	`address6` =concat(person_id, ' XXXX6'),
	`address7` = concat(person_id, ' XXXX7'),
	`address8` =concat(person_id, ' XXXX8'),
	`address9` = concat(person_id, ' XXXX9'),
	`address10` = concat(person_id, ' XXXX10'),
	`address11` =  concat(person_id, ' XXXX11'),
	`address12` = concat(person_id, ' XXXX12'),
	`address13` =concat(person_id, ' XXXX13'),
	`address14` = concat(person_id, ' XXXX14'),
	`address15` = concat(person_id, ' XXXX15'),
	date_created = now(),
	date_voided = now();


SET FOREIGN_KEY_CHECKS=1;
