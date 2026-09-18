CREATE VIEW vw_JG_OS AS
-- 2026 
with spolu as (
SELECT
	o.ucet 							as Ucet,
	o.Nazev  						as Nazev,
	--CONCAT(o.ucet,'_',o.nazev) 		as Ucet_Nazev,
	LEFT(o.ucet,1) 					as Trida,
	LEFT (o.ucet,3) 				as Syntetika
FROM
StwPh_10863907_2026.dbo.pOS o
union
-- 2025
SELECT
	o.ucet 							as Ucet,
	o.Nazev  						as Nazev,
--	CONCAT(o.ucet,'_',o.nazev) 		as Ucet_Nazev,
	LEFT(o.ucet,1) 					as Trida,
	LEFT (o.ucet,3) 				as Syntetika
FROM
StwPh_10863907_2025.dbo.pOS o
),
filter as -- vypočet duplicít asi spôsobené názvom účtu v rôznych rokoch 
(
select 
ROW_NUMBER() OVER (PARTITION BY s.Ucet ORDER BY s.Ucet DESC) AS 'rn',
s.*
from spolu s
)
select 
	f.Ucet,
	f.Nazev,
--	f.Ucet_Nazev,
	f.Trida,
	f.Syntetika
from filter f
where f.rn=1;