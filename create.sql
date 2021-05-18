create or replace type class_type_t as object (
    id number(5),
    type varchar(2),
    shifts number(2),
    num_classes number(3),
    hour_shift number(3),
    map member function getClassHours return number
);

create or replace type teaching_dist_t as object(
    nmr number(10),
    id number(10),
    hours number(10),
    factor number(1),
    sequence number(2),
    class_type ref class_type_t
);

create or replace type teaching_dist_tab_t as table of ref teaching_dist_t;

create or replace type teacher_t as object (
    nmr number(10),
    name varchar(80),
    shorthand varchar(10),
    category number(7),
    first_name varchar(50),
    last_name varchar(50),
    status varchar(2),
    teaching_dist teaching_dist_tab_t,
    map member function getHoursFactor return number
);

create or replace type teacher_tab_t as table of ref teacher_t;

alter type class_type_t add attribute teachers teacher_tab_t cascade;

create or replace type class_type_tab_t as table of ref class_type_t;

create or replace type occurrences_t as object (
    code varchar(10),
    school_year varchar(9),
    semester varchar(2),
    enrolled_num number(4),
    with_frequency number(5),
    approved number(4),
    objectives varchar(4000),
    content varchar(4000),
    department varchar(10),
    class_type class_type_tab_t,
    map member function getApprovedPercentage return number
);

create or replace type occurrences_tab_t as table of ref occurrences_t;

create or replace type courses_t as object (
    code varchar(10),
    name varchar(120),
    initials varchar(10),
    course_number number(5),
    occurrences occurrences_tab_t
);

create table Class_Type of class_type_t
    nested table teachers store as teacher_tab;
    
create table Teaching_Dist of teaching_dist_t;

create table Teacher of teacher_t
    nested table teaching_dist store as teaching_dist_tab;

create table Occurrences of occurrences_t
    nested table class_type store as class_types_tab;
    
create table Courses of courses_t
    nested table occurrences store as occurrences_tab;

create type body class_type_t as 
    map member function getClassHours return number is 
        begin 
            return hour_shift * shifts;
        end getClassHours;
end;

create type body teaching_dist_t as 
    member function getHoursFactor return number is 
        begin 
            return hours * factor;
        end getHoursFactor;
end;

create type body occurrences_t as 
    member function getApprovedPercentage return number is 
        begin 
            return (approved/enrolled_num) * 100;
        end calculatePercentage;
end;