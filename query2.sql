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