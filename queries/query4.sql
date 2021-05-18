select value(occ).school_year, value(t).category, round(avg(value(td).hours), 3)
from occurrences occ, table(value(occ).class_type) ct, table(value(ct).teachers) t, table(value(t).teaching_dist) td
where regexp_like (value(occ).school_year, '^200[1-4]') and
    value(ct).id = value(td).id and
    value(t).category is not null
group by value(occ).school_year, value(t).category
order by value(occ).school_year, value(t).category