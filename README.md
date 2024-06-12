# Calmar

La macro SAS CALMAR (CALage sur MARges) permet de redresser un échantillon provenant d'une enquête par sondage, par repondération des individus, en utilisant une information auxiliaire disponible sur un certain nombre de variables, appelées variables de calage. Le redressement consiste à remplacer les pondérations initiales (ou "poids de sondage") par de nouvelles pondérations telles que :
- pour une variable de calage catégorielle (ou "qualitative"), les effectifs des modalités de la variable estimés dans l'échantillon, après redressement, seront égaux aux effectifs connus sur la population ;
- pour une variable numérique (ou "quantitative"), le total de la variable estimé dans l'échantillon, après redressement, sera égal au total connu sur la population.

Le redressement consiste à remplacer les pondérations initiales, qui sont en général les "poids de sondage" des individus (égaux aux inverses des probabilités d'inclusion), par des "poids de calage" (appelés aussi pondérations finales par la suite) aussi proches que possible des pondérations initiales au sens d'une certaine distance, et satisfaisant les égalités indiquées plus haut.

Lorsque les variables servant au redressement sont toutes catégorielles, le redressement consiste à "caler" les "marges" du tableau croisant toutes les variables sur des effectifs connus, d'où le nom de la macro.

Cette méthode de redressement permet de réduire la variance d'échantillonnage, et, dans certains cas, de réduire le biais dû à la non réponse totale. 

Les principaux contributeurs à l'élaboration de cette macro sont Jean-Claude Deville et Carl-Erik Särndal pour la théorie du calage sur marges, et Olivier Sautory pour le développement de la macro CALMAR permettant sa mise en œuvre.

La documentation (disponible ici en français et en anglais) expose succinctement les aspects théoriques du calage sur marges et détaille sa mise en oeuvre pratique, avec des exemples.

La compilation du code source mis à disposition ici s'effectue via les trois lignes de code suivantes :

    libname lib_calm 'Z:\Calmar';    
    options mstored sasmstore=lib_calm;    
    %include 'Z:\Calmar\Calmar.sas';

où dans cet exemple, le code source de la macro (fichier Calmar.sas) est stocké dans le répertoire « Z:\Calmar », qui contiendra aussi la version compilée de la macro.

Pour utiliser ensuite cette version compilée de la macro dans un autre programme, il suffit de l'appeler en début de ce programme via les deux lignes de codes suivantes :

    libname lib_calm 'Z:\Calmar';    
    options mstored sasmstore=lib_calm;   

Note : la macro CALMAR utilise les modules SAS/STAT et SAS/IML du logiciel SAS.
