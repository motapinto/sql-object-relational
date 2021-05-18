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