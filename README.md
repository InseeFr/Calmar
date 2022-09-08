# Calmar

La macro SAS CALMAR (CALage sur MARges) permet de redresser un échantillon provenant d'une enquête par sondage, par re pondération des individus, en utilisant une information auxiliaire disponible sur un certain nombre de variables, appelées variables de calage. Le redressement consiste à remplacer les pondérations initiales (ou "poids de sondage") par de nouvelles pondérations telles que :
- pour une variable de calage catégorielle (ou "qualitative"), les effectifs des modalités de la variable estimés dans l'échantillon, après redressement, seront égaux aux effectifs connus sur la population ;
- pour une variable numérique (ou "quantitative"), le total de la variable estimé dans l'échantillon, après redressement, sera égal au total connu sur la population.

Cette méthode de redressement permet de réduire la variance d'échantillonnage, et, dans certains cas, de réduire le biais dû à la non réponse totale. 

La macro SAS CALMAR est disponible sous forme compilée pour différentes versions de SAS sur le [site de l'Insee](https://www.insee.fr/fr/information/2021902).
