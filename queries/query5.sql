select value(o).school_year as school_year, 
    value(o).semester as semester, sum(value(cl).hour_shift) as hour_shift 
from occurrences o, table(value(o).class_type) cl
where value(cl).num_classes is not null and 
    value(cl).shifts is not null and 
    value(o).semester like '%S'
group by value(o).school_year, value(o).semester
order by value(o).school_year, value(o).semester