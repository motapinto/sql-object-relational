insert into Class_Type (id, type, shifts, num_classes, hour_shift)
select id, tipo, turnos, n_aulas, horas_turno
from XTIPOSAULA;

insert into Teaching_Dist (nmr, id, hours, factor, sequence, class_type)
select nr, ct.id, horas, fator, ordem, ref(ct)
from XDSD xdsd, Class_Type ct
where ct.id = xdsd.id;

insert into Teacher (nmr, name, shorthand, category, first_name, last_name, status)
select nr, nome, sigla, categoria, proprio, apelido, estado
from XDOCENTES;

insert into Occurrences (code, school_year, semester, enrolled_num, with_frequency, approved, objectives, content, department)
select codigo, ano_letivo, semestero, inscritos, com_frequencia, aprovados, objetivos, conteudo, departamento
from XOCORRENCIAS;

insert into Courses (code, name, initials, course_number)
select codigo, designacao, sigla_uc, curso
from XUCS;

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