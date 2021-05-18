select c.code, c.name, value(o).semester as semester, round(value(o).getApprovedPercentage(), 3) as percentage_approved
from courses c, table(value(c).occurrences) o
where regexp_like(value(c).name, '(\d)* Matemática(\d)*') and 
    value(o).enrolled_num is not null and
    value(o).approved is not null and
    regexp_like(value(o).school_year, '^200[3-4]') and
    value(o).department is not null
order by c.code, c.name