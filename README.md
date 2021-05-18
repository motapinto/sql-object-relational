# Teaching Service SQL - Object Relational model

## Table of Contents
* [Introduction](#Introduction)
* [Object Relational Schema](#Object-Relational-Schema)
* [Object Relational Data Model](#Object-Relational-Data-Model)
    * [Types](#Types)
    * [Methods](#Methods)
* [Populating](#Populating)
    * [Insert scripts](#Insert-scripts)
    * [Insert nested tables](#Insert-nested-tables)
* [Introduction](#Introduction)
* [Queries](#Queries)
    * [Query 1](#Query-1)
        * SQL Formulation
        * Result
        * Description
    * [Query 2](#Query-2)
        * SQL Formulation
        * Result
        * Description
    * [Query 3](#Query-3)
        * SQL Formulation
        * Result
        * Description
    * [Query 4](#Query-4)
        * SQL Formulation
        * Result
        * Description
    * [Query 5](#Query-5)
        * SQL Formulation
        * Result
        * Description
    * [Query 6](#Query-6)
        * SQL Formulation
        * Result
        * Description
* [Conclusion](#Conclusion)    
    
## Introduction
This project consists on the design of the object relational data model for a teaching service. We start by showing our design for the schema and follow it with the necessary DDL statements to setup and populate the object types, and explain our approach for each query.

###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>

## Object Relational Schema
![](https://i.imgur.com/CUmISK1.png)

## Object Relational Data Model
### Types
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
```sql
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
```
Here, we deal with the types from the tables **XDOCENTES**, **XDSD** and **XTIPOSAULA**. In our approach, the class_type_t is referenced in teaching_dist_t. Aditionally, the teaching_dist_t is also referenced in the teacher_t. Finally the teacher_t is linked with the class_type_t using a nested table by adding an attribute to the class_type_t (**CIRCULARITY**)

```sql
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
```

In this second section, we create the object type occurrences_t (from **XOCORRENCIAS**) which contains the class_type nested table. The same is done for the courses_t (from **XUCS**) that contains the occurrences nested table.

```sql
create table Class_Type of class_type_t
    nested table teachers store as teacher_tab;
    
create table Teaching_Dist of teaching_dist_t;

create table Teacher of teacher_t
    nested table teaching_dist store as teaching_dist_tab;

create table Occurrences of occurrences_t
    nested table class_type store as class_types_tab;
    
create table Courses of courses_t
    nested table occurrences store as occurrences_tab;
```
Finally, we create the object tables, giving a name to the auxiliary hidden tables that store the nested tables.


### Methods
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
``` sql
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
```
We decided to create some object methods that would help us in the queries ahead: `getClassHours` is a class_type object method that calculates the number of class hours by multiplying hour_shift by shift, returning the calculated value; `getHoursFactor` is a teaching_dist object method that calculates the teacher's class hours by multiplying hours by factor, returning the calculated value; Finally, `getApprovedPercentage` is a occurrences object method that calculates the percentage of approved students by dividing the number of approved students by the number of enrolled students and multiplying it by 100.

## Populating

### Insert scripts
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
```sql
insert into Class_Type (id, type, shifts, num_classes, hour_shift)
select id, tipo, turnos, n_aulas, horas_turno
from GTD10.XTIPOSAULA;

insert into Teaching_Dist (nmr, id, hours, factor, sequence, class_type)
select nr, ct.id, horas, fator, ordem, ref(ct)
from GTD10.XDSD xdsd, Class_Type ct
where ct.id = xdsd.id;

insert into Teacher (nmr, name, shorthand, category, first_name, last_name, status)
select nr, nome, sigla, categoria, proprio, apelido, estado
from GTD10.XDOCENTES;

insert into Occurrences (code, school_year, semester, enrolled_num, with_frequency, approved, objectives, content, department)
select codigo, ano_letivo, semestero, inscritos, com_frequencia, aprovados, objetivos, conteudo, departamento
from GTD10.XOCORRENCIAS;

insert into Courses (code, name, initials, course_number)
select codigo, designacao, sigla_uc, curso
from GTD10.XUCS;
```
Using the object constructors previously mentioned we can insert the data directly into them.

### Insert nested tables
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>

```sql
update Class_Type ta
set ta.teachers = cast(multiset(
    select ref(t)
    from Teacher t, Teaching_Dist td
    where ta.id = td.id and 
        t.nmr = td.nmr
) as teacher_tab_t);

update Teacher t
set t.teaching_dist = cast(multiset(
    select ref(x)
    from Teaching_Dist x
    where t.nmr = x.nmr
) as teaching_dist_tab_t);

update Occurrences o
set o.class_type = cast(multiset(
    select ref(ta)
    from class_type ta, GTD10.xtiposaula xta 
    where ta.id = xta.id and
     o.code = xta.codigo and
     o.school_year = xta.ano_letivo and
     o.semester = xta.periodo
) as class_type_tab_t);    

update Courses c
set c.occurrences = cast(multiset(
    select ref(o)
    from occurrences o
    where o.code = c.code
) as occurrences_tab_t);
````
Finally, to add the references to the nested tables we update each one of the previously created tables.

## Queries

### Query 1
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**How many class hours of each type did the program 233 got in year 2004/2005?**

#### SQL Formulation
```sql
select value(ct).type as type, sum(value(ct).getClassHours()) as classHours
from courses c, table(value(c).occurrences) o, table(value(o).class_Type) ct
where value(c).course_number = 233 and 
    value(o).school_year = '2004/2005'
group by value(ct).type
```

#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "TYPE",
          "type" : "VARCHAR2"
        },
        {
          "name" : "CLASSHOURS",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "type" : "P",
          "classhours" : 587
        },
        {
          "type" : "TP",
          "classhours" : 703
        },
        {
          "type" : "T",
          "classhours" : 308
        }
      ]
    }
  ]
}
```
#### Description
In this query, for the school year of 2004/2005 and for the course whose number is 233, we calculate the sum of class hours with the use of the `getClassHours()` method for each class type (i.e. P, TP, and T).

### Query 2
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**Which courses (show the code, total class hours required, total classes assigned) have a difference between total class hours required and the service actually assigned in year 2003/2004?**

#### SQL Formulation
```sql
select q1.code, q1.classHours as requiredHours, q2.hours as assignedHours
from (
    select c.code as code, sum(value(ct).getClassHours()) as classHours
    from courses c, table(value(c).occurrences) o, table(value(o).class_type) ct
    where value(o).school_year = '2003/2004'
    group by c.code
) q1, (
    select c.code as code, sum(value(td).hours) as hours
    from courses c, table(value(c).occurrences) o, table(value(o).class_type) ct, table(value(ct).teachers) t, table(value(t).teaching_dist) td
    where value(o).school_year = '2003/2004' and
        value(ct).id = value(td).id and
        value(t).nmr = value(td).nmr
    group by c.code
) q2
where q1.code = q2.code and 
    q1.classHours <> q2.hours
```
#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "CODE",
          "type" : "VARCHAR2"
        },
        {
          "name" : "REQUIREDHOURS",
          "type" : "NUMBER"
        },
        {
          "name" : "ASSIGNEDHOURS",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "code" : "EEC5020",
          "requiredhours" : 1,
          "assignedhours" : 0
        },
        {
          "code" : "MGI1204",
          "requiredhours" : 5,
          "assignedhours" : 3
        },
        {
          "code" : "EMG2204",
          "requiredhours" : 7,
          "assignedhours" : 8
        },
        {
          "code" : "EIC5101",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "MEA208",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MEEC1076",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEEC1075",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EMG4105",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MTM109",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EMG5205",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MEST208",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "MEST209",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "EIC5202",
          "requiredhours" : 48,
          "assignedhours" : 30
        },
        {
          "code" : "MEM170",
          "requiredhours" : 2,
          "assignedhours" : 4
        },
        {
          "code" : "MEM185",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "MRSC1104",
          "requiredhours" : 1,
          "assignedhours" : 2
        },
        {
          "code" : "EEC4277",
          "requiredhours" : 4,
          "assignedhours" : 1
        },
        {
          "code" : "EM631",
          "requiredhours" : 10,
          "assignedhours" : 9
        },
        {
          "code" : "EM613",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "EEC3161",
          "requiredhours" : 13,
          "assignedhours" : 14
        },
        {
          "code" : "EC4104",
          "requiredhours" : 20,
          "assignedhours" : 22
        },
        {
          "code" : "EMG2202",
          "requiredhours" : 7,
          "assignedhours" : 6
        },
        {
          "code" : "MEA400",
          "requiredhours" : 8,
          "assignedhours" : 9
        },
        {
          "code" : "MEEC1085",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EEC5180",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "MTM100",
          "requiredhours" : 6,
          "assignedhours" : 5
        },
        {
          "code" : "EEC4248",
          "requiredhours" : 9,
          "assignedhours" : 10
        },
        {
          "code" : "MEEC2103",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EEC5145",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "MEEC1055",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EI1100",
          "requiredhours" : 4,
          "assignedhours" : 3
        },
        {
          "code" : "MRSC1204",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MMCCE1214",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEB100",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "MFAMF1101",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "EEC3265",
          "requiredhours" : 13,
          "assignedhours" : 14
        },
        {
          "code" : "MRPE1204",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "EEC5040",
          "requiredhours" : 11,
          "assignedhours" : 0
        },
        {
          "code" : "EEC4161",
          "requiredhours" : 15,
          "assignedhours" : 16
        },
        {
          "code" : "EMG1103",
          "requiredhours" : 10,
          "assignedhours" : 11
        },
        {
          "code" : "MMI1201",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MMI1102",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EMG2001",
          "requiredhours" : 6,
          "assignedhours" : 3
        },
        {
          "code" : "EMG4103",
          "requiredhours" : 2,
          "assignedhours" : 5
        },
        {
          "code" : "MGI1210",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "EMG5204",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "EEC5278",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "EQ502",
          "requiredhours" : 12,
          "assignedhours" : 0
        },
        {
          "code" : "EQ101",
          "requiredhours" : 28,
          "assignedhours" : 8
        },
        {
          "code" : "MEA301",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "EIC4213",
          "requiredhours" : 1,
          "assignedhours" : 2
        },
        {
          "code" : "MEEC1051",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EI1101",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EI1201",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EI1206",
          "requiredhours" : 4,
          "assignedhours" : 1
        },
        {
          "code" : "EM128",
          "requiredhours" : 24,
          "assignedhours" : 25
        },
        {
          "code" : "MEB200",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EM229",
          "requiredhours" : 34,
          "assignedhours" : 28
        },
        {
          "code" : "MMI1204",
          "requiredhours" : 3,
          "assignedhours" : 13
        },
        {
          "code" : "MMI1101",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EIC5102",
          "requiredhours" : 7,
          "assignedhours" : 4
        },
        {
          "code" : "MMCCE1205",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEA406",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "EEC5277",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "EEC4145",
          "requiredhours" : 8,
          "assignedhours" : 9
        },
        {
          "code" : "MEEC1088",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MGI1203",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EEC5127",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "MEST314",
          "requiredhours" : 2,
          "assignedhours" : 4
        },
        {
          "code" : "EQ103",
          "requiredhours" : 17,
          "assignedhours" : 18
        },
        {
          "code" : "GEI205",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EEC4290",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "MEEC1054",
          "requiredhours" : 3,
          "assignedhours" : 1
        },
        {
          "code" : "MMCCE1213",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EC1108",
          "requiredhours" : 60,
          "assignedhours" : 65
        },
        {
          "code" : "EEC4244",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "EEC4101",
          "requiredhours" : 18,
          "assignedhours" : 19
        },
        {
          "code" : "EMG1202",
          "requiredhours" : 7,
          "assignedhours" : 8
        },
        {
          "code" : "MMI1103",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEA407",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "EEC4250",
          "requiredhours" : 5,
          "assignedhours" : 7
        },
        {
          "code" : "EEC5250",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "MEEC1089",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EM337",
          "requiredhours" : 36,
          "assignedhours" : 33
        },
        {
          "code" : "MEST211",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "EEC5060",
          "requiredhours" : 11,
          "assignedhours" : 0
        },
        {
          "code" : "EMM527",
          "requiredhours" : 40,
          "assignedhours" : 0
        },
        {
          "code" : "EM114",
          "requiredhours" : 39,
          "assignedhours" : 26
        },
        {
          "code" : "EQ109",
          "requiredhours" : 17,
          "assignedhours" : 18
        },
        {
          "code" : "MEEC2102",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EMG3105",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MEAM1200",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEEC1050",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EI1202",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EI1203",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EI1208",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MRSC1201",
          "requiredhours" : 5,
          "assignedhours" : 3
        },
        {
          "code" : "EM335",
          "requiredhours" : 31,
          "assignedhours" : 26
        },
        {
          "code" : "EIC4101",
          "requiredhours" : 24,
          "assignedhours" : 14
        },
        {
          "code" : "EEC4273",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MEA311",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MEEC2094",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "EEC5021",
          "requiredhours" : 16,
          "assignedhours" : 17
        },
        {
          "code" : "EMG4202",
          "requiredhours" : 5,
          "assignedhours" : 6
        },
        {
          "code" : "MAIC1101",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "MAIC1107",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "GEI210",
          "requiredhours" : 4,
          "assignedhours" : 2
        },
        {
          "code" : "EEC5243",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "EIC4212",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EI1209",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "MMCCE1102",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEST115",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "GEI213",
          "requiredhours" : 9,
          "assignedhours" : 8
        },
        {
          "code" : "MEA306",
          "requiredhours" : 3,
          "assignedhours" : 2
        },
        {
          "code" : "MEEC2095",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEEC1078",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEEC1072",
          "requiredhours" : 3,
          "assignedhours" : 4
        },
        {
          "code" : "MEB107",
          "requiredhours" : 3,
          "assignedhours" : 5
        },
        {
          "code" : "EMG1001",
          "requiredhours" : 12,
          "assignedhours" : 6
        },
        {
          "code" : "MEM176",
          "requiredhours" : 2,
          "assignedhours" : 3
        },
        {
          "code" : "EIC4217",
          "requiredhours" : 4,
          "assignedhours" : 5
        },
        {
          "code" : "EIC5120",
          "requiredhours" : 4,
          "assignedhours" : 6
        },
        {
          "code" : "EC5183",
          "requiredhours" : 6,
          "assignedhours" : 3
        },
        {
          "code" : "EMG3102",
          "requiredhours" : 7,
          "assignedhours" : 5
        },
        {
          "code" : "MEST302",
          "requiredhours" : 2,
          "assignedhours" : 3
        }
      ]
    }
  ]
}
```
#### Description
We had two options for this query in which we could choose between using views or using just one sql DDL statement.
In our first approach we decided to use two views with the objective to have a simpler query. After analysing the execution plans, we noticed that the cost was relatively higher than the one we got without using the views, so we decided to choose the second option. 
For this option, we needed to calculate the sum of the class hours (including all different class types) for a given course, during the year of 2003/2004 and then check if the value calculated was different than the number of (planned) required hours for that course.

### Query 3
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**Who is the professor with more class hours for each type of class, in the academic year 2003/2004? Show the number and name of the professor, the type of class and the total of class hours times the factor.**

#### SQL Formulation
```sql
select q1.nmr, q2.name, q1.type, q1.max_hours
from (
    select max(nmr) as nmr, type, max(total_hours) as max_hours
    from (
        select value(t).nmr as nmr, value(ct).type as type, sum(value(td).getHoursFactor()) as total_hours
        from occurrences occ, table(value(occ).class_type) ct, table(value(ct).teachers) t, table(value(t).teaching_dist) td
        where occ.school_year = '2003/2004' and
            value(ct).id = value(td).id and
            value(t).nmr = value(td).nmr
            group by value(t).nmr, value(ct).type
    )
    group by type
) q1, (
    select nmr as nmr, name as name
    from teacher t
) q2
where q1.nmr = q2.nmr
```
#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "NMR",
          "type" : "NUMBER"
        },
        {
          "name" : "NAME",
          "type" : "VARCHAR2"
        },
        {
          "name" : "TYPE",
          "type" : "VARCHAR2"
        },
        {
          "name" : "MAX_HOURS",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "nmr" : 908100,
          "name" : "Armínio de Almeida Teixeira",
          "type" : "P",
          "max_hours" : 30
        },
        {
          "nmr" : 246626,
          "name" : "Jorge Manuel Gomes Barbosa",
          "type" : "OT",
          "max_hours" : 4
        },
        {
          "nmr" : 908290,
          "name" : "José Manuel Miguez Araújo",
          "type" : "TP",
          "max_hours" : 26
        },
        {
          "nmr" : 909330,
          "name" : "Nuno Filipe da Cunha Nogueira",
          "type" : "T",
          "max_hours" : 34
        }
      ]
    }
  ]
}
```
#### Description
We had two options for this query in which we could choose between using views or using just one sql DDL statement.
In our first approach we decided to use two views with the objective to have a simpler query. After analysing the execution plans, we noticed that the cost was relatively higher than the one we got without using the views, so we decided to choose the second option. 
For this option, we calculate the sum of the teacher's class hours with the use of the object method `getHoursFactor()` for the school year of 2003/2004. Finally, for each class type (i.e. P, OT, TP, T), we filter the teachers by the maximum sum value.

### Query 4
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**Which is the average number of hours by professor by year in each category, in the years between 2001/2002 and 2004/2005?**

#### SQL Formulation
```sql
select value(occ).school_year, value(t).category, round(avg(value(td).hours), 3)
from occurrences occ, table(value(occ).class_type) ct, table(value(ct).teachers) t, table(value(t).teaching_dist) td
where regexp_like (value(occ).school_year, '^200[1-4]') and
        value(ct).id = value(td).id and
        value(t).category is not null
group by value(occ).school_year, value(t).category
order by value(occ).school_year, value(t).category
```
#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "SCHOOL_YEAR",
          "type" : "VARCHAR2"
        },
        {
          "name" : "CATEGORY",
          "type" : "NUMBER"
        },
        {
          "name" : "AVERAGE",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "school_year" : "2001/2002",
          "category" : 103,
          "average" : 2.25
        },
        {
          "school_year" : "2001/2002",
          "category" : 107,
          "average" : 2.258
        },
        {
          "school_year" : "2001/2002",
          "category" : 110,
          "average" : 2.62
        },
        {
          "school_year" : "2001/2002",
          "category" : 111,
          "average" : 2.688
        },
        {
          "school_year" : "2001/2002",
          "category" : 112,
          "average" : 1.5
        },
        {
          "school_year" : "2001/2002",
          "category" : 116,
          "average" : 3.283
        },
        {
          "school_year" : "2001/2002",
          "category" : 117,
          "average" : 3.673
        },
        {
          "school_year" : "2001/2002",
          "category" : 119,
          "average" : 4.755
        },
        {
          "school_year" : "2001/2002",
          "category" : 120,
          "average" : 3.869
        },
        {
          "school_year" : "2001/2002",
          "category" : 122,
          "average" : 4.5
        },
        {
          "school_year" : "2001/2002",
          "category" : 124,
          "average" : 4
        },
        {
          "school_year" : "2001/2002",
          "category" : 144,
          "average" : 2
        },
        {
          "school_year" : "2001/2002",
          "category" : 374,
          "average" : 5
        },
        {
          "school_year" : "2001/2002",
          "category" : 519,
          "average" : 3.9
        },
        {
          "school_year" : "2001/2002",
          "category" : 520,
          "average" : 6.333
        },
        {
          "school_year" : "2001/2002",
          "category" : 565,
          "average" : 2
        },
        {
          "school_year" : "2001/2002",
          "category" : 11005,
          "average" : 5.75
        },
        {
          "school_year" : "2001/2002",
          "category" : 19995,
          "average" : 1.667
        },
        {
          "school_year" : "2001/2002",
          "category" : 19997,
          "average" : 2.231
        },
        {
          "school_year" : "2001/2002",
          "category" : 19999,
          "average" : 3.081
        },
        {
          "school_year" : "2002/2003",
          "category" : 103,
          "average" : 2
        },
        {
          "school_year" : "2002/2003",
          "category" : 107,
          "average" : 2.247
        },
        {
          "school_year" : "2002/2003",
          "category" : 110,
          "average" : 2.556
        },
        {
          "school_year" : "2002/2003",
          "category" : 111,
          "average" : 2.722
        },
        {
          "school_year" : "2002/2003",
          "category" : 112,
          "average" : 5.2
        },
        {
          "school_year" : "2002/2003",
          "category" : 116,
          "average" : 3.231
        },
        {
          "school_year" : "2002/2003",
          "category" : 117,
          "average" : 3.404
        },
        {
          "school_year" : "2002/2003",
          "category" : 119,
          "average" : 4.386
        },
        {
          "school_year" : "2002/2003",
          "category" : 120,
          "average" : 3.831
        },
        {
          "school_year" : "2002/2003",
          "category" : 122,
          "average" : 4.5
        },
        {
          "school_year" : "2002/2003",
          "category" : 125,
          "average" : 4
        },
        {
          "school_year" : "2002/2003",
          "category" : 144,
          "average" : 2.111
        },
        {
          "school_year" : "2002/2003",
          "category" : 374,
          "average" : 3.75
        },
        {
          "school_year" : "2002/2003",
          "category" : 519,
          "average" : 3.333
        },
        {
          "school_year" : "2002/2003",
          "category" : 520,
          "average" : 6.5
        },
        {
          "school_year" : "2002/2003",
          "category" : 565,
          "average" : 2
        },
        {
          "school_year" : "2002/2003",
          "category" : 903,
          "average" : 2
        },
        {
          "school_year" : "2002/2003",
          "category" : 10801,
          "average" : 1
        },
        {
          "school_year" : "2002/2003",
          "category" : 11005,
          "average" : 4
        },
        {
          "school_year" : "2002/2003",
          "category" : 11007,
          "average" : 4
        },
        {
          "school_year" : "2002/2003",
          "category" : 19995,
          "average" : 1.857
        },
        {
          "school_year" : "2002/2003",
          "category" : 19997,
          "average" : 2.375
        },
        {
          "school_year" : "2002/2003",
          "category" : 19999,
          "average" : 2.263
        },
        {
          "school_year" : "2003/2004",
          "category" : 103,
          "average" : 2.167
        },
        {
          "school_year" : "2003/2004",
          "category" : 107,
          "average" : 2.312
        },
        {
          "school_year" : "2003/2004",
          "category" : 110,
          "average" : 2.464
        },
        {
          "school_year" : "2003/2004",
          "category" : 111,
          "average" : 2.625
        },
        {
          "school_year" : "2003/2004",
          "category" : 112,
          "average" : 4.125
        },
        {
          "school_year" : "2003/2004",
          "category" : 116,
          "average" : 3.051
        },
        {
          "school_year" : "2003/2004",
          "category" : 117,
          "average" : 3.366
        },
        {
          "school_year" : "2003/2004",
          "category" : 119,
          "average" : 5.104
        },
        {
          "school_year" : "2003/2004",
          "category" : 120,
          "average" : 3.57
        },
        {
          "school_year" : "2003/2004",
          "category" : 122,
          "average" : 4.5
        },
        {
          "school_year" : "2003/2004",
          "category" : 144,
          "average" : 1.833
        },
        {
          "school_year" : "2003/2004",
          "category" : 374,
          "average" : 3
        },
        {
          "school_year" : "2003/2004",
          "category" : 519,
          "average" : 3.143
        },
        {
          "school_year" : "2003/2004",
          "category" : 565,
          "average" : 2.167
        },
        {
          "school_year" : "2003/2004",
          "category" : 903,
          "average" : 2.25
        },
        {
          "school_year" : "2003/2004",
          "category" : 10108,
          "average" : 2
        },
        {
          "school_year" : "2003/2004",
          "category" : 10119,
          "average" : 2
        },
        {
          "school_year" : "2003/2004",
          "category" : 11005,
          "average" : 4.667
        },
        {
          "school_year" : "2003/2004",
          "category" : 11007,
          "average" : 0
        },
        {
          "school_year" : "2003/2004",
          "category" : 19995,
          "average" : 2.2
        },
        {
          "school_year" : "2003/2004",
          "category" : 19997,
          "average" : 1.778
        },
        {
          "school_year" : "2003/2004",
          "category" : 19999,
          "average" : 2.228
        },
        {
          "school_year" : "2004/2005",
          "category" : 103,
          "average" : 2.143
        },
        {
          "school_year" : "2004/2005",
          "category" : 107,
          "average" : 2.466
        },
        {
          "school_year" : "2004/2005",
          "category" : 110,
          "average" : 2.37
        },
        {
          "school_year" : "2004/2005",
          "category" : 111,
          "average" : 4.438
        },
        {
          "school_year" : "2004/2005",
          "category" : 112,
          "average" : 3.143
        },
        {
          "school_year" : "2004/2005",
          "category" : 116,
          "average" : 3.034
        },
        {
          "school_year" : "2004/2005",
          "category" : 117,
          "average" : 3.081
        },
        {
          "school_year" : "2004/2005",
          "category" : 119,
          "average" : 6
        },
        {
          "school_year" : "2004/2005",
          "category" : 120,
          "average" : 3.785
        },
        {
          "school_year" : "2004/2005",
          "category" : 122,
          "average" : 3.667
        },
        {
          "school_year" : "2004/2005",
          "category" : 144,
          "average" : 1.706
        },
        {
          "school_year" : "2004/2005",
          "category" : 374,
          "average" : 8
        },
        {
          "school_year" : "2004/2005",
          "category" : 519,
          "average" : 3.071
        },
        {
          "school_year" : "2004/2005",
          "category" : 565,
          "average" : 4
        },
        {
          "school_year" : "2004/2005",
          "category" : 903,
          "average" : 1.667
        },
        {
          "school_year" : "2004/2005",
          "category" : 10108,
          "average" : 2
        },
        {
          "school_year" : "2004/2005",
          "category" : 10119,
          "average" : 3
        },
        {
          "school_year" : "2004/2005",
          "category" : 11007,
          "average" : 2
        },
        {
          "school_year" : "2004/2005",
          "category" : 19995,
          "average" : 4.333
        },
        {
          "school_year" : "2004/2005",
          "category" : 19997,
          "average" : 2.143
        },
        {
          "school_year" : "2004/2005",
          "category" : 19999,
          "average" : 2.169
        }
      ]
    }
  ]
}
```
#### Explanation
In this query we calculate the average number each teacher has for a given category from 2001/2002 until 2004/2005.


### Query 5
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**Which is the total hours per week, on each semester, that an hypothetical student enrolled in every course of a single curricular year from each program would get?**

#### SQL Formulation
```sql
select value(o).school_year as school_year, 
    value(o).semester as semester, sum(value(cl).hour_shift) as hour_shift 
from occurrences o, table(value(o).class_type) cl
where value(cl).num_classes is not null and 
    value(cl).shifts is not null and 
    value(o).semester like '%S'
group by value(o).school_year, value(o).semester
order by value(o).school_year, value(o).semester
```
#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "SCHOOL_YEAR",
          "type" : "VARCHAR2"
        },
        {
          "name" : "SEMESTER",
          "type" : "VARCHAR2"
        },
        {
          "name" : "HOUR_SHIFT",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "school_year" : "1996/1997",
          "semester" : "1S",
          "hour_shift" : 6
        },
        {
          "school_year" : "1996/1997",
          "semester" : "2S",
          "hour_shift" : 6
        },
        {
          "school_year" : "2002/2003",
          "semester" : "1S",
          "hour_shift" : 1438
        },
        {
          "school_year" : "2002/2003",
          "semester" : "2S",
          "hour_shift" : 1317
        },
        {
          "school_year" : "2003/2004",
          "semester" : "1S",
          "hour_shift" : 1431
        },
        {
          "school_year" : "2003/2004",
          "semester" : "2S",
          "hour_shift" : 1402
        },
        {
          "school_year" : "2004/2005",
          "semester" : "1S",
          "hour_shift" : 1723
        },
        {
          "school_year" : "2004/2005",
          "semester" : "2S",
          "hour_shift" : 1483
        },
        {
          "school_year" : "2005/2006",
          "semester" : "1S",
          "hour_shift" : 1745
        },
        {
          "school_year" : "2005/2006",
          "semester" : "2S",
          "hour_shift" : 1510
        },
        {
          "school_year" : "2006/2007",
          "semester" : "1S",
          "hour_shift" : 1538
        },
        {
          "school_year" : "2006/2007",
          "semester" : "2S",
          "hour_shift" : 979
        }
      ]
    }
  ]
}
```

#### Explanation
For this query, we considered every school year and the occurrencies related to every semester (i.e. 1S and 2S). From these occurrencies, the corresponding class types and sum of total number of shift hours were selected, since it's assumed that a student only takes part in one of the shifts. 

### Query 6
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
**Query that illustrates the use of OR extensions.**
*What is the approved percentage of UC's that have 'Matemática' in their name during the school year of 2003/2004*


#### SQL Formulation
```sql
select c.code, c.name, value(o).semester as semester, round(value(o).getApprovedPercentage(), 3) as percentage_approved
from courses c, table(value(c).occurrences) o
where regexp_like(value(c).name, '(\d)* Matemática(\d)*') and 
    value(o).enrolled_num is not null and
    value(o).approved is not null and
    regexp_like(value(o).school_year, '^200[3-4]') and
    value(o).department is not null
order by c.code, c.name
```
#### Result (in JSON format)
```json
{
  "results" : [
    {
      "columns" : [
        {
          "name" : "CODE",
          "type" : "VARCHAR2"
        },
        {
          "name" : "NAME",
          "type" : "VARCHAR2"
        },
        {
          "name" : "SEMESTER",
          "type" : "VARCHAR2"
        },
        {
          "name" : "PERCENTAGE_APPROVED",
          "type" : "NUMBER"
        }
      ],
      "items" : [
        {
          "code" : "EC1101",
          "name" : "Análise Matemática 1",
          "semester" : "1S",
          "percentage_approved" : 48.16
        },
        {
          "code" : "EC1207",
          "name" : "Análise Matemática 2",
          "semester" : "2S",
          "percentage_approved" : 50.158
        },
        {
          "code" : "EC2103",
          "name" : "Análise Matemática 3",
          "semester" : "1S",
          "percentage_approved" : 66.187
        },
        {
          "code" : "EEC1102",
          "name" : "Análise Matemática I",
          "semester" : "1S",
          "percentage_approved" : 56.867
        },
        {
          "code" : "EEC1201",
          "name" : "Análise Matemática II",
          "semester" : "2S",
          "percentage_approved" : 30.853
        },
        {
          "code" : "EEC2101",
          "name" : "Análise Matemática III",
          "semester" : "1S",
          "percentage_approved" : 43.291
        },
        {
          "code" : "EIC1107",
          "name" : "Análise Matemática",
          "semester" : "1S",
          "percentage_approved" : 52.105
        },
        {
          "code" : "EM125",
          "name" : "Análise Matemática I",
          "semester" : "1S",
          "percentage_approved" : 54.924
        },
        {
          "code" : "EM127",
          "name" : "Análise Matemática II",
          "semester" : "2S",
          "percentage_approved" : 53.846
        },
        {
          "code" : "EM223",
          "name" : "Análise Matemática III",
          "semester" : "1S",
          "percentage_approved" : 41.071
        },
        {
          "code" : "EM224",
          "name" : "Análise Matemática IV",
          "semester" : "2S",
          "percentage_approved" : 30.672
        },
        {
          "code" : "EMG1102",
          "name" : "Análise Matemática I",
          "semester" : "1S",
          "percentage_approved" : 18.667
        },
        {
          "code" : "EMG1201",
          "name" : "Análise Matemática II",
          "semester" : "2S",
          "percentage_approved" : 43.21
        },
        {
          "code" : "EMM106",
          "name" : "Análise Matemática",
          "semester" : "2S",
          "percentage_approved" : 40.741
        },
        {
          "code" : "EQ100",
          "name" : "Análise Matemática I",
          "semester" : "1S",
          "percentage_approved" : 51.923
        },
        {
          "code" : "EQ105",
          "name" : "Análise Matemática II",
          "semester" : "2S",
          "percentage_approved" : 59.13
        },
        {
          "code" : "EQ205",
          "name" : "Análise Matemática III",
          "semester" : "1S",
          "percentage_approved" : 63.81
        },
        {
          "code" : "GEI110",
          "name" : "Análise Matemática I",
          "semester" : "1S",
          "percentage_approved" : 88.235
        },
        {
          "code" : "GEI111",
          "name" : "Análise Matemática II",
          "semester" : "2S",
          "percentage_approved" : 83.784
        },
        {
          "code" : "GEI209",
          "name" : "Análise Matemática III",
          "semester" : "1S",
          "percentage_approved" : 61.538
        },
        {
          "code" : "GEI210",
          "name" : "Análise Matemática IV",
          "semester" : "2S",
          "percentage_approved" : 64.444
        }
      ]
    }
  ]
}
```

#### Explanation
In this query, we decided to calculate the percentage of approved students (with the use of the object method `getApprovedPercentage()`) from every course that has 'Matemática' in their name during the school year of 2003/2004. We also found a useful method in `regexp_like` while searching through the Oracle SQL Developer documentation that enabled us to filter through the course names and the school year with the usage of regular expressions. This is a query that demonstrates the full usage of OR extensions. 

## Conclusion
###### *Shortcut:* <ins>[To the top](#Table-of-Contents)</ins>
This work has shown us that having an Object Relational approach can vastly impact the performance of the queries. Although being impactful, our group had some difficulties finding the optimal model, leading to test different relational models using different approaches. Nonetheless, we consider that we successfully carried out the intended work while also learning a lot about Object Relational during this project. In future work, we can further improve the results and keep learning.
