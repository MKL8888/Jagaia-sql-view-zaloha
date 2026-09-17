-- dbo.vw_UD_CZ_SK_detail_act source

CREATE VIEW vw_JG_UD_CZ_detail AS
With base_ud_cz AS -- základné dáta z učetního deníku PHD CZ 
--2026
(SELECT 
		ud.id,						-- pre porovnanie riadkov       
        ud.Datum					as Datum_UD,  
        ud.Cislo					AS Cislo_Dokladu,
        fa.Cislo					AS Cislo_Faktury,
        Fa.CisloObj					AS Cislo_Objednavky,
        fa.SText 					as Text_Faktury,
		ud.RelUDAg					AS Typ_Dokladu,		
		ud.ParSym					AS Cislo_dokumentu_dodavatele,
		fa.PDoklad					AS Cislo_prijatej_fa,
        ud.UMD,
		ud.UD,
		ud.Firma,
        ud.Jmeno,
        ud.CisloZAK,
        ud.ParICO,
        ud.DatSave,
        ud.DatCreate,
        ud.SText					as Text_zauctovani,
        ud.kc
from [StwPh_10863907_2026].[dbo].[pUD] ud
LEFT JOIN [StwPh_10863907_2026].[dbo].[FA] fa ON ud.RelUdAg IN (2,3) AND fa.Cislo = ud.Cislo
union ALL 
-- 2025
SELECT 
		ud.id,						-- pre porovnanie riadkov       
        ud.Datum					as Datum_UD,  
        ud.Cislo					AS Cislo_Dokladu,
        fa.Cislo					AS Cislo_Faktury,
        Fa.CisloObj					AS Cislo_Objednavky,
        fa.SText 					as Text_Faktury,
		ud.RelUDAg					AS Typ_Dokladu,		
		ud.ParSym					AS Cislo_dokumentu_dodavatele,
		fa.PDoklad					AS Cislo_prijatej_fa,
        ud.UMD,
		ud.UD,
		ud.Firma,
        ud.Jmeno,
        ud.CisloZAK,
        ud.ParICO,
        ud.DatSave,
        ud.DatCreate,
        ud.SText					as Text_zauctovani,
        ud.kc
from [StwPh_10863907_2025].[dbo].[pUD] ud
LEFT JOIN [StwPh_10863907_2025].[dbo].[FA] fa ON ud.RelUdAg IN (2,3) AND fa.Cislo = ud.Cislo
)
,
base_ud AS 							-- základné dáta z učetního deníku spojene, doplnene o upravy formatov a vypocty
(
    SELECT
        CAST(ud.Datum_UD AS date) 	AS Datum_UD,
        ud.Cislo_Dokladu,
        ud.Cislo_Faktury,
        ud.Cislo_Objednavky,
        ud.Typ_Dokladu,
        CASE
            WHEN ud.Firma IS NULL
 			OR ud.Jmeno IS NULL
            THEN COALESCE(ud.Firma, ud.Jmeno)
            ELSE CONCAT(ud.Firma,'_',ud.Jmeno)
  END 								AS Firma_Jmeno,
      	ud.Cislo_dokumentu_dodavatele,
		ud.Cislo_prijatej_fa,
        x.Strana, 					-- rozpočítana strana účtu MD/D
        x.Ucet, 					-- číslo účtu
        x.Castka 					as Castka_kc, 				-- čiastka bez úpravy znamienka
      	ud.CisloZAK 				as Cislo_zakazky,
        ud.ParICO 					as ICO ,
        CAST (ud.DatSave as date) 	as Datum_zmeny,
        cast (ud.DatCreate as date) as Datum_vytvoreni,
        ud.Text_zauctovani,
        COALESCE (skpp.SText, skpv.SText, ud.Text_Faktury) 
      								as Text_Dokladu			-- doplní sa nenulový podľa zdroja dát
    FROM base_ud_cz ud
    LEFT JOIN StwPh_10863907_2026.dbo.SKPP skpp ON ud.Typ_Dokladu = 6 AND skpp.Cislo = ud.Cislo_Dokladu
	LEFT JOIN StwPh_10863907_2026.dbo.SKPV skpv ON ud.Typ_Dokladu = 7 AND skpv.Cislo = ud.Cislo_Dokladu
        CROSS APPLY
		( VALUES
		      ('MD', ud.UMD, ud.Kc),
		      ('D' , ud.UD , ud.Kc)
		) x(Strana,Ucet,Castka)
),
uct_denik AS
(
    SELECT
        b.Datum_UD,
        b.Datum_zmeny,
		b.Datum_vytvoreni,
        b.Cislo_Dokladu,
        b.Cislo_Faktury,
        b.Cislo_Objednavky,
        b.Typ_Dokladu,
        b.Firma_Jmeno,
    	b.ICO,
        b.Text_zauctovani,
        b.Text_Dokladu,
        b.Cislo_dokumentu_dodavatele,
        b.Cislo_prijatej_fa,
        b.Ucet,
        b.Strana,
        b.Castka_kc,				-- čiastka bezo zmeny znamienka, tak ako je v účtovnom deníku
        CASE
            WHEN LEFT(b.Ucet,1) IN ('5','6')
                 AND b.Strana = 'MD'
                THEN -b.Castka_kc
            WHEN LEFT(b.Ucet,1) IN ('5','6')
                 AND b.Strana = 'D'
                THEN b.Castka_kc
        END 						AS Castka_kc_N_V_HV,			-- pre výpočty nákladov a výnosov a hospodárskeho výsledku
        CASE
            WHEN Strana = 'MD'
                THEN -b.Castka_kc
            ELSE b.Castka_kc
        END 						AS Castka_kc_MD_D,			-- pre konečný stav účtu bez ohľadu na triedu
-- výpočty z pq
    -- Faktúry vydané pozitívna čiastka
	    CASE
	        WHEN b.Castka_kc > 0
		         AND b.Strana = 'D'
		         AND ((b.Ucet LIKE '601%'-- s JT skontrolovať a doplniť komentáre, prečo je účet vylúčený
		         AND b.Ucet NOT LIKE '6013%')
		         OR b.Ucet LIKE '602%'
		         OR b.Ucet LIKE '604%')
	        THEN b.Castka_kc
	        ELSE 0
	    END 							AS FAV_plus,
    -- Faktúrvy vydané negatívna čiastka
    CASE
        WHEN b.Castka_kc < 0
	         AND b.Strana = 'D'
	         AND (b.Ucet LIKE '601%'
	         OR b.Ucet LIKE '602%'
	         OR b.Ucet LIKE '604%')
        THEN b.Castka_kc
        ELSE 0
    END 								AS FAV_minus,
    -- Faktúry prijaté
    CASE
        WHEN b.Strana = 'MD'
        	 AND b.Ucet LIKE '51%'
        THEN b.Castka_kc
        ELSE 0
    END 								AS FAP,
    -- COGS -- náklady na výrobu produktov
    CASE
        WHEN b.Strana = 'MD'
	         AND (b.Ucet LIKE '501%'
	         OR b.Ucet LIKE '582%'
	         OR b.Ucet LIKE '583%')
        THEN b.Castka_kc
        ELSE 0
    END 								AS COGS,
    -- Hospodársky výsledok
    CASE
        WHEN
	     b.Ucet LIKE '5%'
	         OR b.Ucet LIKE '6%'
	         OR b.Ucet LIKE '383%'
	         OR b.Ucet LIKE '389%'
        THEN
             CASE
                WHEN b.Strana = 'MD' THEN -b.Castka_kc
                WHEN b.Strana = 'D'  THEN  b.Castka_kc
                ELSE 0
             END
        ELSE 0
    END 								AS HV,
    -- Obrat
    CASE
        WHEN b.Strana = 'MD' THEN b.Castka_kc
        WHEN b.Strana = 'D'  THEN -b.Castka_kc
        ELSE 0
    END 								AS Obrat,
    -- Náklady
    CASE
        WHEN b.Ucet LIKE '5%'
        	 AND b.Strana = 'MD'
        THEN b.Castka_kc
        WHEN b.Ucet LIKE '5%'
         	 AND b.Strana = 'D'
        THEN -b.Castka_kc
        ELSE 0
    END 								AS Naklady,
    -- Výnosy
    CASE
        WHEN b.Ucet LIKE '6%'
         	 AND b.Strana = 'MD'
        THEN b.Castka_kc
        WHEN b.Ucet LIKE '6%'
         	 AND b.Strana = 'D'
        THEN -b.Castka_kc
        ELSE 0
    END 								AS Vynosy,
    -- Výdaje
    CASE
        WHEN b.Strana = 'MD'
	         AND (b.Ucet LIKE '020%'
	         OR b.Ucet LIKE '040%'
	         OR b.Ucet LIKE '050%'
             )
        THEN b.Castka_kc
        ELSE 0
    END 								AS Vydaje
 FROM base_ud b
        )
SELECT 
u.*,
u.Naklady + u.Vydaje as 'Cerpani',
CASE 
	when u.FAV_plus+u.FAV_minus+u.FAP+u.COGS <> 0 then 'zahrnuto' else 'nezahrnuto' 
END as 'Zahrnuto_AC'
FROM uct_denik u;