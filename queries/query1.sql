select value(ct).type as type, sum(value(ct).getClassHours()) as classHours
from courses c, table(value(c).occurrences) o, table(value(o).class_Type) ct
where value(c).course_number = 233 and 
    value(o).school_year = '2004/2005'
group by value(ct).type