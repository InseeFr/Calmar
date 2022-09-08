%MACRO CALMAR (
DATA      =       , /* Table SAS en entrée                                    */
M         = 1     , /* Méthode utilisée                                       */
POIDS     =       , /* Pondération initiale (poids de sondage Dk)             */
POIDSFIN  =       , /* Pondération finale   (poids de calage Wk)              */
PONDQK    = __UN  , /* Pondération Qk                                         */
LABELPOI  =       , /* Label de la pondération finale                         */
DATAPOI   =       , /* Table contenant la pondération finale                  */
MISAJOUR  =  OUI  , /* Mise à jour de la table &DATAPOI si elle existe déjà   */
CONTPOI   =  OUI  , /* Contenu de la table précedente                         */
LO        =       , /* Borne inférieure (méthode logit ou linéaire tronquée)  */
UP        =       , /* Borne supérieure (méthode logit ou linéaire tronquée)  */
EDITPOI   =  NON  , /* Edition des poids par combinaison de valeurs           */
STAT      =  OUI  , /* Statistiques sur les poids                             */
OBSELI    =  NON  , /* Stockage des observations éliminées dans une table     */
IDENT     =       , /* Identifiant des observations                           */
DATAMAR   =       , /* Table SAS contenant les marges des variables de calage */
PCT       =  NON  , /* PCT = OUI si les marges sont en pourcentages           */
EFFPOP    =       , /* Effectif de la population (si PCT = OUI)               */
CONT      =  OUI  , /* Si CONT = OUI des controles sont effectués             */
MAXITER   =   15  , /* Nombre maximum d'itérations                            */
NOTES     =  NON  , /* par défaut : options NONOTES                           */
SEUIL     = 0.0001  /* Seuil pour le test d'arret                             */
)/store;
/*********************************************************************************/
/* La version du 10/09/2009 accepte plus de 999 variables de calage numériques   */ 
/* (jusqu'à 9999).                                                               */ 
/*********************************************************************************/
/* La version du 21/12/2006 accepte plus de 999 modalités pour les variables     */
/* de calage catégorielles (jusqu'à 9999).                                       */ 
/*********************************************************************************/
/* La version du 11/08/2006 accepte plus de 99 variables de calage catégorielles */ 
/* et plus de 99 variables de calage numériques (jusqu'à 999).                   */ 
/*********************************************************************************/

%put ;                                                                                          
%put ***************************************************; 
%put ** macro CALMAR : Version du 16/06/2015          **;
%put ** (pour calages sur 9999 variables numériques)  **;
%put ***************************************************;
%put ;
%put ; 


%if %upcase(&notes) = OUI %then
%do;
  options notes;
%end;
%else
%do;
  options nonotes;
%end;

   /******************************************************************
    ***  La macro NOBS permet d'affecter le nombre d'observations  ***
    ***  d'une table SAS &DATA à la macro-variable &NOMVAR         ***
    ***  (à condition que le paramètre &DATA ne contienne pas      ***
    ***   les conditions FIRSTOBS, OBS ou WHERE)                   ***
    ******************************************************************/

%macro nobs(data,nomvar);

%global &nomvar;
DATA _NULL_;
  if 0 then set &DATA nobs=nbobs;
  call symput("&nomvar",left(put(nbobs,10.)));
  stop;
run;

%mend nobs;

   /*************************************************************************
    ***  La macro EXISTE permet de savoir si une table SAS &DATA existe   ***
    ***  ou non : la macro-variable &EXISTE vaut OUI ou NON selon le cas  ***
    *************************************************************************/

%macro existe(data,existe);

%global &existe;
%let &existe=non;
DATA _NULL_;
  if 0 then set &DATA;
  stop;
run;
%if &syserr=0 %then %let &existe=oui;

%mend existe;

   /********************************************
    ***  Edition des paramètres de la macro  ***
    ********************************************/

DATA _NULL_;
  file print;
  put //@28 "**********************************";
  put   @28 "***   Paramètres de la macro   ***";
  put   @28 "**********************************";
  put //@2 "Table en entrée                     DATA      =  %upcase(&data)";
  put   @2 " Pondération initiale               POIDS     =  %upcase(&poids)";
  put   @2 " Pondération Qk                     PONDQK    =  %upcase(&pondqk)";
  put   @2 " Identifiant                        IDENT     =  %upcase(&ident)";
  put  /@2 "Table des marges                    DATAMAR   =  %upcase(&datamar)";
  put   @2 " Marges en pourcentages             PCT       =  %upcase(&pct)";
  put   @2 " Effectif de la population          EFFPOP    =  &effpop";
  put  /@2 "Méthode utilisée                    M         =  &m";
  put   @2 " Borne inférieure                   LO        =  &lo";
  put   @2 " Borne supérieure                   UP        =  &up";
  put   @2 " Seuil d'arrêt                      SEUIL     =  &seuil";
  put   @2 " Nombre maximum d'itérations        MAXITER   =  &maxiter";
  put  /@2 "Table contenant la pond. finale     DATAPOI   =  %upcase(&datapoi)";
  put  @2 " Mise à jour de la table DATAPOI    MISAJOUR  =  %upcase(&misajour)";
  put  @2 " Pondération finale                 POIDSFIN  =  %upcase(&poidsfin)";
  put   @2 " Label de la pondération finale     LABELPOI  =  &labelpoi";
  put   @2 " Contenu de la table DATAPOI        CONTPOI   =  %upcase(&contpoi)";
  put  /@2 "Edition des poids                   EDITPOI   =  %upcase(&editpoi)";
  put   @2 " Statistiques sur les poids         STAT      =  %upcase(&stat)";
  put  /@2 "Contrôles                           CONT      =  %upcase(&cont)";
  put   @2 "Table contenant les obs. éliminées  OBSELI    =  %upcase(&obseli)";
  put   @2 "Notes SAS                           NOTES     =  %upcase(&notes)";

   /*************************************************************************
    ***  Controles lorsque l'on veut conserver les pondérations finales   ***
    *************************************************************************/

%if %scan(&datapoi,1) ne %then
%do;

  %if &poidsfin = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 66*"*";
      put @2 "***   ERREUR : le paramètre POIDSFIN n'est pas renseigné"
          @65"***";
      put @2 "***            alors que le paramètre DATAPOI"
             " vaut %upcase(&DATAPOI)" @65 "***";
      put @2 66*"*";
    %goto FIN;
  %end;

   /*  Si la table &DATAPOI contient un point  */

  %if %index(&datapoi,.) ne 0 %then
  %do;

    %let base=%scan(&datapoi,1,.);
    %let table=%scan(&datapoi,2,.);

    PROC CONTENTS noprint data=&base.._all_;
    run;

    %if &syserr ne 0 %then                        /*  Le DDNAME n'existe pas  */
    %do;
      DATA _NULL_;
        file print;
        put //@2 "*************************************************************"
                 "*******";
        put @2 "***   ERREUR : le paramètre DATAPOI vaut %upcase(&datapoi),"
               " mais"  @67 "***";
        put @2 "***            aucune base n'est allouée au DDNAME"
               " %upcase(&base)"
            @67 "***";
        put @2 "**************************************************************"
               "******";
        %goto FIN;
    %end;

    %if &syserr =  0 %then                              /*  Le DDNAME existe  */
    %do;
      DATA &BASE..______un;
      run;
      %if &syserr ne 0 %then
      %do;
        %put %str( ********************************************************);
        %put %str( ***   ERREUR : pas d%'accès en écriture sur la base ) ;
        %put %str( ***            allouée au DDNAME %upcase(&base) )      ;
        %put %str( ***            spécifié dans le paramètre DATAPOI ) ;
        %put %str( ********************************************************);
        %goto FIN;
      %end;
      %else
      %do;
        PROC DATASETS ddname=&BASE NOLIST;
          delete ______un;
        run;
      %end;
    %end;
  %end;
%end;

   /*   Fin des contrôles   */

   /*************************************************************************
    ***  Premiers controles (facultatifs) sur les paramètres de la macro  ***
    *************************************************************************/

%if %upcase(&cont)=OUI %then
%do;

   /*  Controles sur le paramètre DATA  */

  %if %scan(&data,1)= %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "**********************************************************";
      put   @2 "***   ERREUR : le paramètre DATA n'est pas renseigné   ***";
      put   @2 "**********************************************************";
    %goto FIN;
  %end;

  %if %scan(&data,1) ne  %then
  %do;
    %existe(&data,exdata)
    %if &exdata=non %then
    %do;
      DATA _NULL_;
        file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la table %upcase (&data)"  @73 "***";
        put @2 "***            spécifiée dans le paramètre DATA n'existe pas"
            @73 "***";
        put @2 74*"*";
      %goto FIN;
    %end;


  %end;

%end;

   /*   Fin des premiers contrôles facultatifs   */

   /*   La PROC CONTENTS sera utilisée dans les contrôles facultatifs
        et au moment de la lecture de la table DATAMAR                  */

  PROC CONTENTS noprint data=%scan(&DATA,1,'(')
                out=__NOMVAR(keep=name type rename=(name=var));


************************************** MODIF *********************************;

DATA __NOMVAR;
set __NOMVAR;
var=upcase(var);

*********************************** FIN MODIF *********************************;
 
  PROC SORT data=__NOMVAR;
    by var;

   /**************************************************************************
    ***  Suite des controles (facultatifs) sur les paramètres de la macro  ***
    *************************************************************************/

%if %upcase(&cont)=OUI %then
%do;

   /*  Controles sur le paramètre DATAMAR  */

  %if %scan(&datamar,1)= %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "*************************************************************";
      put   @2 "***   ERREUR : le paramètre DATAMAR n'est pas renseigné   ***";
      put   @2 "*************************************************************";
    %goto FIN;
  %end;

  %if %scan(&datamar,1) ne   %then
  %do;
    %existe(&datamar,exmar)
    %if &exmar=non %then
    %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put   @2 "***   ERREUR : la table %upcase (&datamar)" @73 "***";
      put   @2 "***            spécifiée dans le paramètre DATAMAR n'existe pas"
            @73 "***";
      put   @2 74*"*";
      %goto FIN;
    %end;
  %end;

   /*  Controles sur le paramètre M  */

  %if &m ne 1 and &m ne 2 and &m ne 3 and &m ne 4 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***************************************************";
      put   @2 "***   ERREUR : la valeur du paramètre M (&m)    ***";
      put   @2 "***            est différente de 1, 2, 3 et 4   ***";
      put   @2 "***************************************************";
    %goto FIN;
  %end;

  %if (&m=3 or &m=4) and %scan(&lo,1) = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***********************************************************";
      put   @2 "***   ERREUR : le paramètre M vaut (&m)                 ***";
      put   @2 "***            et le paramètre LO n'est pas renseigné   ***";
      put   @2 "***********************************************************";
    %goto FIN;
  %end;

  %if (&m=3 or &m=4) and %scan(&up,1) = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***********************************************************";
      put   @2 "***   ERREUR : le paramètre M vaut (&m)                 ***";
      put   @2 "***            et le paramètre UP n'est pas renseigné   ***";
      put   @2 "***********************************************************";
    %goto FIN;
  %end;

   /*  Controle sur le paramètre EFFPOP  */

  %if &effpop = and %upcase(&pct)=OUI %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "*************************************************************";
      put   @2 "***   ERREUR : le paramètre EFFPOP n'est pas renseigné    ***";
      put   @2 "***            alors que les marges sont données en       ***";
      put   @2 "***            pourcentages (le paramètre PCT vaut OUI)   ***";
      put   @2 "*************************************************************";
    %goto FIN;
  %end;

   /*  Controles sur les variables de la table DATA  */

  %if &poids ne %then
  %do;
    %let poidscar=;
    DATA __POIDS;
      set __NOMVAR(where=(var="%upcase(&poids)"));
      call symput("poidscar",type);
    run;

    %nobs(__poids,expoids)

    %if &expoids=0 %then
    %do;
      DATA _NULL_;
        file print;
          put //@2 74*"*";
          put @2 "***   ERREUR : la variable %upcase(&poids) spécifiée dans le"
              @73 "***";
          put @2 "***            paramètre POIDS ne figure pas dans"  @73 "***";
          put @2 "***            la table %upcase(&data)" @73 "***";
          put @2 74*"*";
      %goto FIN;
    %end;

    %else %if &poidscar=2 %then
    %do;
      DATA _NULL_;
        file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la variable %upcase(&poids) spécifiée dans le"
               " paramètre POIDS" @73 "***";
        put @2 "***            et figurant dans la"                 @73 "***";
        put @2 "***            table %upcase(&data)"                @73 "***";
        put @2 "***            n'est pas numérique"                 @73 "***";
        put @2 74*"*";
      %goto FIN;
    %end;
  %end;

  %if &pondqk ne and &pondqk ne __UN %then
  %do;
    %let pondqcar=;
    DATA __PONDQK;
      set __NOMVAR(where=(var="%upcase(&pondqk)"));
      call symput("pondqcar",type);
    run;

    %nobs(__pondqk,expondqk)

    %if &expondqk=0 %then
    %do;
      DATA _NULL_;
        file print;
          put //@2 74*"*";
          put @2 "***   ERREUR : la variable %upcase(&pondqk) spécifiée dans le"
              @73 "***";
          put @2 "***            paramètre PONDQK ne figure pas dans" @73 "***";
          put @2 "***            la table %upcase(&data)" @73 "***";
          put @2 74*"*";
      %goto FIN;
    %end;

    %else %if &pondqcar=2 %then
    %do;
      DATA _NULL_;
        file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la variable %upcase(&pondqk) spécifiée dans"
               " le paramètre PONDQK"  @73 "***";
        put @2 "***            et figurant dans la"                 @73 "***";
        put @2 "***            table %upcase(&data)"                @73 "***";
        put @2 "***            n'est pas numérique"                 @73 "***";
        put @2 74*"*";
      %goto FIN;
    %end;
  %end;

  %if &ident ne %then
  %do;
    DATA __IDENT;
      set __NOMVAR(where=(var="%upcase(&ident)"));
    run;

    %nobs(__ident,exident)

    %if &exident=0 %then
    %do;
      DATA _NULL_;
        file print;
          put //@2 74*"*";
          put @2 "***   ERREUR : la variable %upcase(&ident) spécifiée dans le"
              @73 "***";
          put @2 "***            paramètre IDENT ne figure pas dans"  @73 "***";
          put @2 "***            la table %upcase(&data)" @73 "***";
          put @2 74*"*";
      %goto FIN;
    %end;
  %end;

   /*  Controles sur les variables de la table DATAMAR  */

  DATA __MARG__;
    set &DATAMAR;
    if _n_=2 then stop;

  DATA _NULL_;
    set __MARG__(keep=var obs=0);
  run;

  %if &syserr ne 0 %then
  %do;
    DATA _NULL_;
      file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la variable VAR ne figure pas dans la" @73 "***";
        put @2 "***            table %upcase(&datamar)"               @73 "***";
        put @2 "***            spécifiée dans le paramètre DATAMAR"   @73 "***";
        put @2 74*"*";
    %goto FIN;
  %end;

  DATA _NULL_;
    set __MARG__(keep=n);
    array v _numeric_;
    call symput('nnum',left(put(dim(v),1.)));
  run;

  %if &syserr ne 0 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : la variable N ne figure pas dans la" @73 "***";
      put @2 "***            table %upcase(&datamar)"             @73 "***";
      put @2 "***            spécifiée dans le paramètre DATAMAR" @73 "***";
      put @2 74*"*";
    %goto FIN;
  %end;

  %else %if &nnum=0 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : la variable N figurant dans la"      @73 "***";
      put @2 "***            table %upcase(&datamar)"             @73 "***";
      put @2 "***            n'est pas numérique"                 @73 "***";
      put @2 74*"*";
    %goto FIN;
  %end;

  DATA __DATAM;
    set &DATAMAR;
    keep var n;
    var=left(upcase(var));

  PROC SORT data=__DATAM out=__DATAMA;
    by var;

  DATA __COMP __NUMCAR;
    merge __NOMVAR(in=in1) __DATAMA(in=in2);
    by var;
    if in2 and not in1 then output __COMP;
    if in1 and in2 and n=0 and type=2 then output __NUMCAR;

  %nobs(__COMP,ncomp)

  %if &ncomp>0 %then
  %do;
    PROC PRINT data=__COMP(keep=var);
      id var;
      title4 "ERREUR : les variables suivantes, dont les noms figurent dans la"
             " variable VAR";
      title5 "de la table %upcase(&datamar)";
      title6 "spécifiée dans le paramètre DATAMAR, n'existent pas";
      title7 "dans la table %upcase(&data)";
      title8 "spécifiée dans le paramètre DATA";
    run;
    %goto FIN;
  %end;

  %else %do;
    %nobs(__NUMCAR,numcar)
    %if &numcar>0 %then
    %do;
      PROC PRINT data=__NUMCAR(drop=type n);
        id var;
        title4 "ERREUR : les variables suivantes sont déclarées comme"
               " numériques (N=0)";
        title5 "de la table %upcase(&datamar)";
        title6 "spécifiée dans le paramètre DATAMAR,";
        title7 "alors que ce sont des variables caractères";
        title8 "dans la table %upcase(&data)";
        title9 "spécifiée dans le paramètre DATA";
       run;
      %goto FIN;
    %end;
  %end;

%end;

   /*  Fin des controles   */

%let niter=0;
%let fini=0;
%let maxdif=1;
%let npoineg=;
%let vc1=;
%let vn1=;
%let nmax=;
%let poineg=0;
%let pbiml=0;
%let arret=0;
%let maxit=0;

   /*  Détermination du nombre maximum de modalités  */

PROC MEANS noprint data=&DATAMAR;
  var n;
  output out=__NMAX max=;

DATA _NULL_;
  set __NMAX;
  n=int(n)*(1-(n<0));
  call symput('nmax',left(put(n,4.)));
run;

%if &nmax=0 %then %let nmax=1;

   /*  Encore un controle sur les variables de la table DATAMAR  */

%if %upcase(&CONT)=OUI %then
%do;

  DATA _NULL_;
    set __MARG__(keep=mar1-mar&nmax);
    array v _numeric_;
    call symput('marnum',left(put(dim(v),4.)));
  run;

  %if &syserr ne 0 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : une (au moins) des variables MAR1 à MAR&nmax"
             " ne figure pas"                                         @73 "***";
      put @2 "***            dans la table %upcase(&datamar)"         @73 "***";
      put @2 "***            spécifiée dans le paramètre DATAMAR"     @73 "***";
      put @2 "***            (&nmax est le nombre maximum de modalités spécifié"
          @73 "***";
      put @2 "***             dans cette table)"  @73 "***";
      put @2 74*"*";

      PROC CONTENTS data=&DATAMAR short;
      title4 "Contenu de la table %upcase(&datamar)";
    %goto FIN;
  %end;

  %else %if &marnum ne &nmax %then
  %do;
    %let marcar=%eval(&nmax-&marnum);
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : parmi les variables MAR1 à MAR&nmax figurant dans"
          @73 "***";
      put @2 "***            la table %upcase(&datamar)"              @73 "***";
      put @2 "***            &marcar ne sont pas numériques"          @73 "***";
      put @2 74*"*";

      PROC CONTENTS data=&DATAMAR;
      title4 "Contenu de la table %upcase(&datamar)";
    %goto FIN;
  %end;

%end;

   /*****************************************
    ***  Lecture de la table SAS DATAMAR  ***
    *****************************************/

************************** MODIF ***************************;

DATA __MAR1BIS(rename=(varbis=var));
set &DATAMAR;
length varbis $32;
varbis=var;
drop var;

**************************************************************;

DATA __MAR1;
  set __MAR1BIS;
  var=left(upcase(var));
  n=int(n)*(1-(n<0));
  type="C";                               /*  variable catégorielle  */
  if n=0 then type="N";                   /*  variable numérique     */
  tot=sum(of mar1-mar&nmax);

   /*  Si les marges des variables catégorielles sont données en effectifs  */

  %if %upcase(&pct) ne OUI %then
  %do;
    if type="C" then
    do;
      array marg marg1-marg&nmax;
      array marge  mar1-mar&nmax;
      array pct  pct1-pct&nmax;
      do over marg;
        pct=marge/tot*100;
        marg=marge;
      end;
    end;
    if type="N" then marg1=mar1;
  %end;

   /*  Si les marges des variables catégorielles sont données en pourcentages */

  %if %upcase(&pct)=OUI %then
  %do;
    if type="C" then
    do;
      array marg marg1-marg&nmax;
      array marge  mar1-mar&nmax;
      array pct  pct1-pct&nmax;
      do over marg;
        marg=marge/100*&effpop;
        pct=marge;
      end;
    end;
    if type="N" then marg1=mar1;
  %end;

   /*  Si CONT vaut OUI, des controles sont effectués  */

%if %upcase(&cont)=OUI %then
%do;

  if type="C" then           /*  les variables MARn sont-elles renseignées ?  */
  do;
    array mar mar1-mar&nmax;
    %let erreur1=0;
    do _i_=1 to n;
       if mar=. then
       do;
         call symput('erreur1','1');
         erreur="*";
       end;
    end;
  end;

  if type="N" then
  do;
    %let erreur3=0;
    if mar1=. then
    do;
      call symput('erreur3','1');
      erreur="*";
    end;
  end;
  run;

  %if &erreur1=1 %then
  %do;
    PROC PRINT data=__MAR1(where=(type="C"));
      id var;
      var n mar1-mar&nmax erreur;
      title4 "ERREUR : pour au moins une variable catégorielle, les marges"
             " MAR1 à MARN,";
      title5 " où N est le nombre de modalités, ne sont pas"
            " toutes renseignées";
    run;
  %end;


  %if &erreur3=1 %then
  %do;
    PROC PRINT data=__MAR1(where=(type="N"));
      id var;
      var n mar1-mar&nmax erreur;
      title4 "ERREUR : pour au moins une variable numérique, la marge"
             " MAR1 n'est pas renseignée";
    run;
  %end;

  %if &erreur1=1 or &erreur3=1 %then %goto FIN;

   /*  Vérification sur les totaux des marges des variables catégorielles  */

  PROC FREQ data=__MAR1(where=(type="C"));
    tables tot/out=__MAR11 noprint;
    title4;

  %nobs(__MAR11,nmar11)

  %if &nmar11>1 %then
  %do;
    PROC PRINT label data=__MAR1(where=(type="C"));
      id var;
      var n mar1-mar&nmax tot;
      label tot=TOT_MARG;
      TITLE4  "ERREUR : les totaux des marges des variables catégorielles "
            "ne sont pas tous égaux";
    run;
    %goto FIN;
  %end;

  %if &nmar11=1 %then
  %do;
    %if %upcase(&pct)=OUI %then
    %do;

      DATA __MAR12;
        set __MAR11;
        errtot=0;
        if abs(tot-100)>0.000001 then errtot=1;
        call symput ("errtot",left(put(errtot,1.)));
      run;

      %if &errtot=1 %then
      %do;

        PROC PRINT label data=__MAR1(where=(type="C"));
          id var;
          var n mar1-mar&nmax tot;
          label tot=TOT_MARG;
          TITLE4  "ERREUR : les totaux des marges des variables catégorielles "
                "ne sont pas égaux à 100";
        run;
        %goto FIN;
      %end;
    %end;

  %end;

%end;

   /*  Fin des controles  */

   /**********************************************************************
    ***  Construction de la table __MAR3 et des macros-variables       ***
    ***  contenant les noms des variables et les nombres de modalités  ***
    **********************************************************************/

PROC SORT data=__MAR1;                   /*  tri par type de variable  */
  by type var;

PROC FREQ data=__MAR1;
  tables type/ out=__LEC1 noprint;

DATA _NULL_;
  set __LEC1;
  %let jj=0;          /*  jj est le nombre de variables catégorielles  */
  %let ll=0;          /*  ll est le nombre de variables numériques     */
  if type="C" then call symput('jj',left(put(count,9.)));
  if type="N" then call symput('ll',left(put(count,9.)));
run;

DATA _NULL_;
  merge __MAR1(where=(type="C") in=in1) __NOMVAR(rename=(type=typesas));
  by var;
  if in1;
  retain k 0;
  k=k+1;
/* Modification du 11/8/2006 pour accepter plus de 99 var. catégorielles      */
/*j=put(k,2.);                                                                */
  j=put(k,3.);
  if k=1 then nn=n;
  else nn=n-1;
  mac="vc"!!left(j); /* Les VCj contiendront les noms des var. catégorielles  */
  mad="m"!!left(j);  /* Les Mj (resp.Nj) contiendront les nombres de modalités*/
  mae="n"!!left(j);  /*(resp. -1, sauf la 1ère) des variables catégorielles   */
  maf="t"!!left(j);  /* Les Tj valent 1 pour une var.num., 2 pour une var.car.*/
  call symput(mac,trim(var));

/*****************************************************/
/* Modification du 21/12/2006 pour prendre en compte */
/* les variables ayant plus de 999 modalités         */
/*****************************************************/
/*call symput(mad,(left(put(n,3.))));                */
  call symput(mad,(left(put(n,4.))));
/*call symput(mae,(left(put(nn,3.))));               */ 
  call symput(mae,(left(put(nn,4.))));
/*****************************************************/

  call symput(maf,(left(put(typesas,1.))));
run;

DATA _NULL_;
  set __MAR1(where=(type="N"));
/* Modification du 11/8/2006 pour accepter plus de 99 var. numériques         */
/*j=put(_n_,2.);                                                              */
/* Modification du 10/9/2009 pour accepter plus de 999 var. numériques        */
/*j=put(_n_,3.);                                                              */
  j=put(_n_,4.);
  mac="vn"!!left(j);   /* Les VNj contiendront les noms des var. numériques   */
  call symput(mac,trim(var));
RUN;

PROC TRANSPOSE data=__MAR1 out=__MAR30;
  by var type notsorted;
  var marg1-marg&nmax;
  title4;

PROC TRANSPOSE data=__MAR1 out=__MAR31;
  by var type notsorted;
  var pct1-pct&nmax;

DATA __MAR3;
  merge __MAR30(rename=(col1=marge)) __MAR31(rename=(col1=pctmarge));

  /*  Calcul de la taille de la taille de la population en présence
      de variables catégorielles                                     */

%if &vc1 ne and %upcase(&pct) ne OUI %then
%do;

  DATA _NULL_;
    set __MAR1(keep=tot obs=1);
    call symput("effpop",left(put(tot,10.)));
  run;

%end;

  /*  Calcul de la taille de l'échantillon si la variable de
      pondération initiale &POIDS est manquante                */

%let pondgen=0;

%if &poids =  and  &vc1 ne %then
%do;

  DATA __MARY;
    set &DATA;
    keep %do j=1 %to &jj; &&vc&j %end;
         %do l=1 %to &ll; &&vn&l %end;
         %if &pondqk ne and &pondqk ne __UN %then
           %do;
             &pondqk
           %end;
    %str(;);
    if nmiss
       (%do j=1 %to &jj; &&vc&j ,%end; %do l=1 %to &ll; &&vn&l , %end;0) = 0
        %if &pondqk ne and &pondqk ne __UN %then
          %do;
            and &pondqk gt 0
          %end;
     %str(;);

  %nobs(__mary,effech)

  %if &effech=0 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : la table %upcase(&DATA)" @73 "***";
      put @2 "***            spécifiée dans le paramètre DATA a 0 observation"
          @73 "***";
      put @2 "***            non éliminée" @73 "***";
      put @2 74*"*";
    %goto FIN;
  %end;

%let pondgen=1;

%end;

   /*  Un nouveau controle ... sur le paramètre POIDS cette fois-ci  */

%if %upcase(&cont)=OUI %then
%do;
  %if &poids = and &vc1 = %then
  %do;
  DATA _NULL_;
    file print;
   put //@2 "*****************************************************************";
    put @2 "***   ERREUR : le paramètre POIDS n'est pas renseigné alors   ***";
    put @2 "***            qu'il n'y a pas de variable catégorielle       ***";
    put @2 "*****************************************************************";
    %goto FIN;
  %end;
%end;

   /**************************************************
    ***  Création de la table de travail __CALAGE  ***
    ***  et de la table __PHI                      ***
    **************************************************/

DATA __CALAGE
  %if %upcase(&obseli)=OUI %then
  %do;
    __OBSELI(keep = %do j=1 %to &jj; &&vc&j %end;
                    %do l=1 %to &ll; &&vn&l %end; &poids &ident &pondqk);
  %end;
  %str(;);
  set &DATA;
  keep %do j=1 %to &jj; &&vc&j %do i=1 %to &&m&j; y&j._&i  %end;%end;
       %do l=1 %to &ll; &&vn&l %end;
       %if &poids =  and  &vc1 ne %then %do;__pond__ %end;
       &poids __un __wfin __poids elim &ident &pondqk;
  __un=1;
  %if &pondgen=1 %then
  %do;
    __pond__=&effpop/&effech;
    __poids=__pond__*&pondqk;
    __wfin=__pond__;
    call symput('poids','__pond__');
  %end;
  %if &poids ne  %then
  %do;
    __poids=&poids*&pondqk;
    __wfin=&poids;
  %end;
  if nmiss
  (%do j=1 %to &jj; &&vc&j ,%end; %do l=1 %to &ll; &&vn&l , %end; __poids)=0
  and __poids gt 0 then elim=0;
  else
  do;
    elim=1;
    %if %upcase(&obseli)=OUI %then
    %do;
      output __OBSELI;
    %end;
  end;

 /*  Création de variables disjonctives à partir des variables catégorielles  */

  %do j=1 %to &jj;
    %if &&t&j=1 %then                    /* cas de variables numériques-SAS  */
      %do i=1 %to &&m&j;
        y&j._&i=(&&vc&j=&i);
      %end;
    %if &&t&j=2 %then                    /* cas de variables caractères-SAS  */
      %do;
        %if &&m&j<10 %then                    /*  moins de 10 modalités  */
        %do i=1 %to &&m&j;
          y&j._&i=(&&vc&j="&i");
        %end;
        %else %if &&m&j<100 %then             /*  de 10 à 99 modalités  */
        %do;
          %do i=1 %to 9;
            y&j._&i=(&&vc&j="0&i");
          %end;
          %do i=10 %to &&m&j;
            y&j._&i=(&&vc&j="&i");
          %end;
        %end;
        %else %if &&m&j<1000 %then            /*  de 100 à 999 modalités  */
        %do;
          %do i=1 %to 9;
            y&j._&i=(&&vc&j="00&i");
          %end;
          %do i=10 %to 99;
            y&j._&i=(&&vc&j="0&i");
          %end;
          %do i=100 %to &&m&j;
            y&j._&i=(&&vc&j="&i");
          %end;
        %end;
		/*****************************************************/
		/* Modification du 21/12/2006 pour prendre en compte */
		/* les variables ayant plus de 999 modalités         */
		/*****************************************************/
		%else          						  /*  de 1000 à 9999 modalités  */
        %do;
          %do i=1 %to 9;
            y&j._&i=(&&vc&j="000&i");
          %end;
          %do i=10 %to 99;
            y&j._&i=(&&vc&j="00&i");
          %end;
          %do i=100 %to 999;
            y&j._&i=(&&vc&j="0&i");
          %end;
          %do i=1000 %to &&m&j;
            y&j._&i=(&&vc&j="&i");
          %end;
        %end;
     %end;
  %end;
output __CALAGE;
run;

   /*   Calcul de l'effectif (non pondéré) de l'échantillon)   */

%nobs(__calage,effinit)

%if &effinit=0 %then
%do;
  DATA _NULL_;
    file print;
    put //@2 74*"*";
    put @2 "***   ERREUR : la table %upcase(&DATA)" @73 "***";
    put @2 "***            spécifiée dans le paramètre DATA a 0 observation"
        @73 "***";
    put @2 74*"*";
  %goto FIN;
%end;

   /*   Calcul des nombres d'observations éliminées et conservées   */

%if &pondgen=1 %then       /*  Nombre d'observations conservées déjà calculé  */
%do;
  %let effelim=%eval(&effinit-&effech);
%end;

%else %do;                  /*  Nombre d'observations conservées non calculé  */

  PROC MEANS data=__CALAGE noprint;
    var elim;
    output out=__EFFELI sum=;

  DATA _NULL_;
    set __EFFELI;
    call symput("effelim",left(put(elim,10.)));
  run;

  %let effech=%eval(&effinit-&effelim);

  %if &effech=0 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 74*"*";
      put @2 "***   ERREUR : la table %upcase(&DATA)" @73 "***";
      put @2 "***            spécifiée dans le paramètre DATA a &effinit"
             " observations..." @73 "***";
      put @2 "***            mais elles sont toutes éliminées !" @73 "***";
      put @2 "***" @73 "***";
      put @2 "***   Une observation de la table en entrée est éliminée dès que"
          " :" @73 "***";
      put @2 "***   - elle a une valeur manquante sur l'une des variables du"
          " calage" @73 "***";
      put @2 "***   - elle a une valeur manquante, négative ou nulle sur l'une"
          @73 "***";
      put @2 "***     des variables de pondération." @73 "***";
      put @2 74*"*";
    %goto FIN;
  %end;
%end;

PROC MEANS data=__CALAGE(where=(elim=0)) noprint;
  var __un
  %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
  %do l=1 %to &ll; &&vn&l   %end;
  %str(;);
  weight __wfin;
  output out=__PHI sum=;

   /***********************************************************
    ***  Impression des marges (population et échantillon)  ***
    ***********************************************************/

PROC TRANSPOSE data=__PHI OUT=__PHI2;

DATA __PHI2;
  set __PHI2(firstobs=3 rename=(col1=echant));
  retain effpond;
  if _n_=1 then
  do;
    effpond=echant;
    call symput("effpond",left(put(echant,10.)));
  end;
  pctech=echant/effpond*100;
run;

%let pb1=0;

DATA __MAR4;
  merge __PHI2(firstobs=2) __MAR3(where=(marge ne .));

********************************** MODIF ****************************;

 /*length var1 $8. modalite $8. modal2 $8.;*/

**************************** FIN MODIF *******************************;

  modal1=substr(_name_,4,5);
  retain j 0;

*********************************** MODIF ****************************;

  if _name_="pct1" then j+1;

********************************* FIN MODIF ***************************;

  %do i=1 %to &jj;
    if j=&i then
    do;
      %if &&t&i=1 %then
      %do;
        modal2=modal1;
      %end;
      %if &&t&i=2 %then
      %do;
        %let long&i=%length(&&m&i);
        modal2=(put(input(modal1,8.),z&&long&i...));
      %end;
    end;
  %end;
  if type="N" then do; pctech=.;modal2=var;var1="VAR.NUM";end;
  if type="C" then do;                     var1=var      ;end;
  modalite=right(modal2);
  if type="C" and echant=0 and marge ne 0 then
  do;
    err="*";
    call symput('pb1','1');
  end;
run;

   /*  Controle sur les effectifs des modalités des variables catégorielles   */

%if %upcase(&cont)=OUI and &vc1 ne %then
%do;

  %let erreur2=0;

  DATA __VERIF;
    set __MAR4(where=(type="C"));
    by var notsorted;
    retain total numero 0;
    if first.var then
    do;
      total=0;
      numero=numero+1;
    end;
    total=total+echant;
    if last.var then
    do;
      total2=total;
      effpond2=effpond;
      if abs(total-effpond)>0.0001 then
      do;
        erreur="*";
        call symput ('erreur2','1');
      end;
    end;
  run;

  %if &erreur2=1 %then
  %do;

    PROC PRINT data=__VERIF SPLIT="*";
      id var;
      label var="Variable"
            modalite="Modalité"
            echant="Marge*échantillon"
            pctech="Pourcentage*échantillon"
            total2="Effectif*cumulé"
            effpond2="Effectif*échantillon"
            erreur="Erreur";
      var modalite echant pctech total2 effpond2 erreur;
      title4  "ERREUR : pour au moins une variable catégorielle, l'effectif"
              " cumulé (pondéré) des modalités n'est pas égal";
      title5  "à l'effectif (pondéré) de l'échantillon";

    DATA __FREQ;
      set __VERIF (where=(erreur="*")  keep=var erreur numero);
      maf="num"!!left(put(_n_,3.));
      call symput(maf,left(put(numero,3.)));
    run;

    %nobs(__freq,nbver)

    PROC FREQ data=__CALAGE(where=(elim=0));
    tables %do k=1 %to &nbver; &&&&vc&&num&k %end;
    %str(;);
    weight &poids;
    title4 "Les effectifs (pondérés) des modalités des variables catégorielles"
           " en erreur";
    run;
    title4;
    %goto FIN;
  %end;

%end;

   /*  Fin du controle  */

PROC PRINT data=__MAR4 SPLIT="*";
  by var1 notsorted;
  id var1;
  label var1="Variable"
        modalite="Modalité*ou variable"
        echant="Marge*échantillon"
        pctech="Pourcentage*échantillon"
        marge="Marge*population"
        pctmarge="Pourcentage*population"
        err="Effectif*nul";
  var modalite echant marge pctech pctmarge
  %if &pb1=1 %then %do; err %end;
  %str(;);
  format pctech pctmarge 6.2;
  title4  "Comparaison entre les marges tirées de l'échantillon (avec la"
          " pondération initiale)";
  title5  "et les marges dans la population (marges du calage)";
  %if &pb1=1 %then
  %do;
    title6 "ERREUR : l'effectif d'une modalité (au moins) d'une variable"
           " catégorielle est nul";
    title7 "alors que la marge correspondante est non nulle : le calage est "
           "impossible";
  %end;
run;
title4;

%if &pb1=1 %then %goto FIN;



   /***************************************************************
    **** Création de la table  __COEFF et des macros variables  ***
    ***  contenant les coefficients du vecteur lambda
    ***************************************************************/

DATA __COEFF;
  length nom $ 8;
  %do j=1 %to &jj;
    %do i=1 %to &&n&j;
      lambda=0;
      nom="c&j._&i";
      call symput(nom,put(lambda,12.));
      output;
    %end;
  %end;

  %do l=1 %to &ll;
      lambda=0;
      nom="cc&l";
      call symput(nom,put(lambda,12.));
      output;
  %end;

run;

   /*  Titre 3  */

 %if &m=1 %then %do; title3 "Méthode : linéaire " %str(;); %end;
 %if &m=2 %then %do; title3 "Méthode : raking ratio" %str(;); %end;
 %if &m=3 %then %do; title3 "Méthode : logit, inf=&lo, sup=&up" %str(;); %end;
 %if &m=4 %then %do; title3 "Méthode : linéaire tronquée, inf=&lo, sup=&up"
 %str(;); %end;
run;

   /**************************************************
    ***********                            ***********
    ***********    DEBUT DES ITERATIONS    ***********
    ***********                            ***********
    **************************************************/

%do %while(&maxdif>&seuil);
%let niter=%eval(&niter+1);

%if &maxiter=%eval(&niter-1) %then
%do;
  DATA _NULL_;
    file print;
    put //@10 "*************************************************************";
    put   @10 "***   Le nombre maximum d'itérations (&maxiter) a été atteint"
          @68 "***";
    put   @10 "***   sans qu'il y ait convergence                        ***";
    put   @10 "*************************************************************";
    call symput('arret','1');
    call symput('maxit','1');
    %goto ARRET;
%end;

   /*  Calcul du vecteur PHI  */

%if &poineg=0 and &niter>1 %then
%do;
  PROC MEANS data=__CALAGE
  %if &niter=1 %then
  %do;
    (where=(elim=0))
  %end;
  noprint;
    var  %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
         %do l=1 %to &ll; &&vn&l   %end;
    %str(;);
    weight __wfin;
    output out=__PHI sum=;
%end;

%if &poineg=1 %then
%do;
  PROC MEANS data=__CALAGE noprint;
    var  %do j=1 %to &jj; %do i=1 %to &&m&j; z&j._&i %end; %end;
         %do l=1 %to &ll; _z&l   %end;
    %str(;);
    weight __wfin;
    output out=__PHI sum=
       %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
       %do l=1 %to &ll; &&vn&l   %end;
  %str(;);
%end;

   /*  Calcul du "tableau de BURT"= matrice PHIPRIM  */

PROC CORR data=__CALAGE
  %if &niter=1 %then
  %do;
    (where=(elim=0))
  %end;
  noprint nocorr sscp out=__BURT(type=sscp);
  var %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
      %do l=1 %to &ll; &&vn&l %end; %str(;);
  with %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
       %do l=1 %to &ll; &&vn&l %end; %str(;);
  weight __poids;
run;

%if &syserr ne 0 %then                /*   Cas de "Floating Point Overflow"   */
%do;
  %put ********************************************************************;
  %put ***   Le calage ne peut etre réalisé. Pour rendre le calage      ***;
  %put ***   possible, vous pouvez :                                    ***;
  %put ***                                                              ***;
  %if &m=3 or &m=4 %then
  %do;
  %put ***   - diminuer la valeur de LO                                 ***;
  %put ***   - augmenter la valeur de UP                                ***;
  %end;
  %if &m=2 or &m=3 or &m=4 %then
  %do;
  %put ***   - utiliser la méthode linéaire (M=1)                       ***;
  %end;
  %if &vc1 ne %then
  %do;
  %put ***   - opérer des regroupements de modalités de variables       ***;
  %put ***     catégorielles                                            ***;
    %if &effpond ne &effpop %then
    %do;
  %put ***   - changer la variable de pondération initiale, car         ***;

  %put ***     l'effectif pondéré de l' échantillon vaut &effpond ;
  %put ***     alors que l effectif de la population vaut &effpop ;

    %end;
  %end;
  %put ********************************************************************;
  %goto FIN;
%end;

   /*******************************
    ***  On entre dans IML ...  ***
    *******************************/

PROC IML;
*reset print;

%if &niter=1 %then                 /*  On construit le vecteur des marges TX  */
%do;
  use __MAR4;
  read all var { marge } into marges;
  %if &&vc1 ne %then               /*  Suppression des marges "redondantes"  */
  %do;
    tx=marges[1:&m1,]
    %do p=2 %to &jj;
      %let pp=%eval(&p-1);
      %let ppp=%eval(&pp-1);
      // marges[ %do q=1 %to &pp;
                     &&n&q +
                  %end;
      &pp: %do q=1 %to &p;
             &&n&q +
           %end;
      &ppp,]
    %end;
    %if &ll ne 0 %then
    %do;
      // marges[ &m1
        %do j=2 %to &jj ;
          + &&m&j
        %end;
        + 1 : &m1
        %do j=2 %to &jj ;
          + &&m&j
        %end;
        + &ll,]
    %end;
    %str(;);
  %end;
  %if &&vc1 = %then
  %do;
    tx=marges;
  %end;
  store tx;
%end;

  use __BURT;                            /*  On construit la matrice PHIPRIM  */
  read point 1;
  read after where(_type_="SSCP") var
  {    %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
       %do l=1 %to &ll; &&vn&l   %end;        }
      into phiprim;
  inverse=inv(phiprim);
  free phiprim;

  if ncol(inverse)=0 then            /*  Cas où PHIPRIM n'est pas inversible  */
  do;
    call symput('pbiml','1');
  end;

  else                               /*  Cas où PHIPRIM est inversible  */
  do;

  use __PHI;                                 /*  On construit le vecteur PHI  */
  read all  var
  {    %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
       %do l=1 %to &ll; &&vn&l   %end;        }
       into phi;
  phi=t(phi);

  %if &niter>1 %then
  %do;
    load tx;
  %end;

  use __COEFF;                      /*  On calcule le nouveau vecteur lambda  */
  read all var "lambda" into lambda;
  lambda=lambda+inverse*(tx-phi);
  edit __COEFF;
  replace all var "lambda";

  end;

   /***************************
    ***  ... on sort d'IML  ***
    ***************************/

   /*   Cas où PHIPRIM n'est pas inversible : l'algorithme s'arrete   */

%if &pbiml=1 and &niter=1 %then              /*  Si c'est la 1ère itération   */
%do;
  DATA _NULL_;
    file print;
    put //@10 "******************************************************";
    put   @10 "***   Les variables analysées sont colinéaires :   ***";
    put   @10 "***   le calage ne peut etre réalisé               ***";
    put   @10 "******************************************************";

                                      /*   Recherche des liaisons linéaires   */

  PROC PRINCOMP data=__CALAGE(where=(elim=0)) cov noint noprint outstat=__VECP1;
    var %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
        %do l=1 %to &ll; &&vn&l %end; %str(;);
    weight __poids;

  PROC TRANSPOSE data=__VECP1(where=(_type_="EIGENVAL") drop=_name_)
                 out=__VECP2;

  DATA __VECP3;
    merge __VECP1(where=(_type_="USCORE")) __VECP2;
    if col1=0;
    array tab1 %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
               %do l=1 %to &ll; &&vn&l %end; %str(;);
    array tab2 %do j=1 %to &jj; %do i=1 %to &&n&j; zy&j._&i %end; %end;
               %do l=1 %to &ll; z&l %end; %str(;);
    do over tab1;tab2=(tab1=0)*2 + (tab1 ne 0)*abs(tab1);end;
    mini=min(of %do j=1 %to &jj; %do i=1 %to &&n&j; zy&j._&i %end; %end;
                %do l=1 %to &ll; z&l %end; );
    do over tab1;tab1=tab1/mini;end;

  PROC PRINT label noobs;
    var %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i %end; %end;
        %do l=1 %to &ll; &&vn&l %end; ;
    label %do j=1 %to &jj; %do i=1 %to &&n&j; y&j._&i=&&vc&j &i %end; %end;;
    title3 "Coefficients de la (ou des) combinaison(s) linéaire(s)"
           " nulle des variables du calage";
    title4 "(une variable de nom WXY 2 désigne la variables indicatrice"
           " associée à la modalité 2 de la variable catégorielle WXY)";
    run;

    %goto FIN;
%end;

%if &pbiml=1 and &niter>1 %then       /*  Si ce n'est pas la 1ère itération   */
%do;
  DATA _NULL_;
    file print;
 put //@5 "*******************************************************************";
 put @5   "***   Le calage ne peut etre réalisé. Pour rendre le calage     ***";
 put @5   "***   possible, vous pouvez :                                   ***";
 put @5   "***                                                             ***";
 %if &m=3 or &m=4 %then
 %do;
 put @5   "***   - diminuer la valeur de LO                                ***";
 put @5   "***   - augmenter la valeur de UP                               ***";
 %end;
 %if &m=2 or &m=3 or &m=4 %then
 %do;
 put @5   "***   - utiliser la méthode linéaire (M=1)                      ***";
 %end;
 %if &vc1 ne %then
 %do;
 put @5   "***   - opérer des regroupements de modalités de variables      ***";
 put @5   "***     catégorielles                                           ***";
 %if &effpond ne &effpop %then
 %do;
 put @5   "***   - changer la variable de pondération initiale, car        ***";
 put @5   "***     l'effectif pondéré de l'échantillon vaut &effpond" @69 "***";
 put @5   "***     alors que l'effectif de la population vaut &effpop"
     @69  "***";
 %end;
 %end;
 put @5   "*******************************************************************";
    call symput('arret','1');
    %goto ARRET;
%end;

   /*  Construction de la table contenant les récapitulatifs des itérations  */

%if &niter=1 %then
%do;
  DATA __RECAP2;
    set __COEFF(keep=lambda nom rename=(lambda=lambda1));
    t=substr(nom,1,2);
    n=substr(nom,2,1);
%end;
%else
%do;
  data __RECAP2;
    merge __RECAP2 __COEFF(keep=lambda rename=(lambda=lambda&niter));
%end;

DATA _NULL_;
  set __COEFF;
  call symput(nom,put(lambda,17.14));
run;

   /******************************************
    ***  Mise à jour de la table __CALAGE  ***
    ******************************************/

DATA __CALAGE;
  set __CALAGE
  %if &niter=1 %then %do; (where=(elim=0)) ;_finit_=1;  %end;
  %else %do;  ;_finit_=_f_; %end;

   /*  Calcul du produit scalaire X*Lambda  */

  xlambda = %do j=1 %to &jj;
            + y&j._1 * &&c&j._1 %do i=2 %to &&n&j; + y&j._&i * &&c&j._&i %end;
            %end;
            %do l=1 %to &ll;  + &&vn&l * &&cc&l
            %end;
  %str(;);

   /*  Calcul de F(x*lambda)  */

  %if &m=1 %then %do; _f_=1 + xlambda*&pondqk; %end;
  %if &m=2 %then %do; _f_= exp(xlambda*&pondqk); %end;
  %if &m=3 %then
  %do;
    _f_=(&lo*(&up-1)+&up*(1-&lo)*exp( xlambda*&pondqk
        *(&up-&lo)/(1-&lo)/(&up-1)))
        /(&up-1+(1-&lo)*exp( xlambda*&pondqk
        *(&up-&lo)/(1-&lo)/(&up-1)))  %str(;);
  %end;
  %if &m=4 %then
  %do;
    _som_=1+ xlambda*&pondqk;
    _f_=max(&lo,_som_)+min(&up,_som_)-_som_; drop _som_;
  %end;

   /*  Calcul de F'(x*lambda)  */

  %if &m=1 %then %do; _fprim_=&pondqk; %end;
  %if &m=2 %then %do; _fprim_=_f_; %end;
  %if &m=3 %then
  %do;
    _fprim_=( ( (&up-&lo)**2 ) *exp( xlambda*&pondqk
            * (&up-&lo)/(1-&lo)/(&up-1)))
            /(((&up-1)+(1-&lo)*exp( xlambda*&pondqk
            * (&up-&lo)/(1-&lo)/(&up-1)))**2) %str(;);
  %end;
  %if &m=4 %then %do; _fprim_=(_f_>&lo)*(_f_<&up); %end;

  __wfin=&poids*_f_;
  __poids=&poids*_fprim_*&pondqk;
  dif=abs(_finit_-_f_);
  poineg=(__wfin<0);

   /*  Cas où il peut exister des poids négatifs  */

%if &m=1 or (&m=3 and %index(&lo,-) ne 0) or (&m=4 and %index(&lo,-) ne 0) %then
%do;
  __zwfin=__wfin;
  array tab1 %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
             %do l=1 %to &ll; &&vn&l %end; __wfin __un;
  array tab2 %do j=1 %to &jj; %do i=1 %to &&m&j; z&j._&i %end; %end;
             %do l=1 %to &ll; _z&l %end; __wfin  __zun;
  if __wfin<0 then
  do;
    do over tab2;tab2=-tab1;end;
  end;
  else
  do;
    do over tab2;tab2= tab1;end;
  end;
%end;

   /*  Calcul du critère d'arret  */

PROC MEANS data=__CALAGE noprint;
  var dif poineg;
  output out=__TESTER max(dif)=test sum(poineg)=poidsneg;

DATA _NULL_;
  set __TESTER;
  if poidsneg>0 then
  do;
    call symput('poineg','1');
  end;
run;

PROC APPEND base=__RECAP1 data=__TESTER;

DATA _NULL_;
  set __TESTER;
  call symput('maxdif',put(test,7.5));
run;

DATA _NULL_;
  file log;
  put /@10 "***************************************************************";
  put  @10 "***   Valeur du critère d'arrêt à l'itération &NITER : &maxdif"
       @70 "***";
  put  @10 "***************************************************************";
  put /;

%if not (&m=1 or (&m=3 and %index(&lo,-) ne 0) or (&m=4 and %index(&lo,-) ne 0))
and &poineg=1 %then
%do;
  DATA _NULL_;
    file print;
 put //@5 "*******************************************************************";
 put @5   "***   Le calage ne peut etre réalisé. Pour rendre le calage     ***";
 put @5   "***   possible, vous pouvez :                                   ***";
 put @5   "***                                                             ***";
 %if &m=3 or &m=4 %then
 %do;
 put @5   "***   - diminuer la valeur de LO                                ***";
 put @5   "***   - augmenter la valeur de UP                               ***";
 %end;
 %if &m=2 or &m=3 or &m=4 %then
 %do;
 put @5   "***   - utiliser la méthode linéaire (M=1)                      ***";
 %end;
 %if &vc1 ne %then
 %do;
 put @5   "***   - opérer des regroupements de modalités de variables      ***";
 put @5   "***     catégorielles                                           ***";
 %if &effpond ne &effpop %then
 %do;
 put @5   "***   - changer la variable de pondération initiale, car        ***";
 put @5   "***     l'effectif pondéré de l'échantillon vaut &effpond" @69 "***";
 put @5   "***     alors que l'effectif de la population vaut &effpop"
     @69  "***";
 %end;
 %end;
    call symput('arret','1');
    %goto ARRET;
%end;

%end;

   /************************************************
    ***********                          ***********
    ***********    FIN DES ITERATIONS    ***********
    ***********                          ***********
    ************************************************/


   /**********************
    ***  Les éditions  ***
    **********************/

%ARRET : ;

   /*  Tableaux récapitulatifs de l'algorithme  */

DATA __RECAP1;
  set __RECAP1 end=fin;
  iter=_n_;
  %if &poineg=1 %then           /*  Récupération du nombre de poids négatifs  */
  %do;
    if fin then
    do;
      call symput('npoineg',left(put(poidsneg,10.)));
    end;
  %end;

PROC PRINT data=__RECAP1 split="*";
 id iter;
 var test poidsneg;
 label test="Critère*d'arrêt"
       poidsneg="Poids*négatifs"
       iter="Itération";
 title4 "Premier tableau récapitulatif de l'algorithme :";
 title5 "la valeur du critère d'arrêt et le nombre de poids négatifs"
         " après chaque itération";

DATA __RECAP2;
  set __RECAP2;
  by t notsorted;
  keep lambda1-lambda&niter;
  if last.t and t ne 'cc' and n ne "1" then
  do;
    output;
    array lambda lambda1-lambda&niter;
    do over lambda;lambda=.;end;
    output;
  end;
  else output;

DATA __RECAP2;
   merge __MAR4(keep=var modalite type) __RECAP2;
   if type="N" then modalite=" ";
   drop type;

PROC PRINT label data=__RECAP2;
   id var;
   label var="Variable"
         modalite="Modalité";
   title4 "Deuxième tableau récapitulatif de l'algorithme :";
   title5 "les coefficients du vecteur lambda de multiplicateurs de Lagrange"
          " après chaque itération";
run;
title4;

%if &arret=1 %then %goto FIN;

   /*  Impression des marges finales  */

%if &poineg=0 %then
%do;
  PROC MEANS data=__CALAGE noprint;
    var __un
        %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
        %do l=1 %to &ll; &&vn&l   %end;
    %str(;);
    weight __wfin;
    output out=__PHI sum=;
%end;

%if &poineg=1 %then
%do;
  PROC MEANS data=__CALAGE noprint;
    var __zun
          %do j=1 %to &jj; %do i=1 %to &&m&j; z&j._&i %end; %end;
          %do l=1 %to &ll; _z&l   %end;
    %str(;);
    weight __wfin;
    output out=__PHI sum= __un
       %do j=1 %to &jj; %do i=1 %to &&m&j; y&j._&i %end; %end;
       %do l=1 %to &ll; &&vn&l   %end;
  %str(;);
%end;

PROC TRANSPOSE data=__PHI out=__PHI2;

DATA __PHI2;
  set __PHI2(firstobs=3 rename=(col1=echant));
  retain effpond;
  if _n_=1 then effpond=echant;
  pctech=echant/effpond*100;

%let pb=0;

DATA __MAR5;
  length var1 $8. modalite $8.;
  merge __PHI2(firstobs=2) __MAR3(where=(marge ne .))
        __MAR4(keep=modalite var1);
  if type="N" then pctech=.;
  /*  if type="C" then do;                       var1=var      ;end;*/
  erreur=" ";
  if abs(marge-echant) > 0.00001  then
  do;
    erreur="*";
    call symput('pb','1');
  end;
run;

%if &pb=1 %then %do;
  DATA _NULL_;
    file print;
    put //@10 "***************************************************************";
    put   @10 "***   ATTENTION : l'algorithme a convergé, mais le calage   ***";
    put   @10 "***               n'est pas parfaitement réalisé            ***";
    put   @10 "***************************************************************";
%end;

PROC PRINT data=__MAR5 split="*";
  by var1 notsorted;
  id var1;
  label var1="Variable"
        modalite="Modalité*ou variable"
        echant="Marge*échantillon"
        pctech="Pourcentage*échantillon"
        marge="Marge*population"
        erreur="Erreur"
        pctmarge="Pourcentage*population";
  var modalite echant marge pctech pctmarge
  %if &pb=1 %then %do; erreur %end;
  %str(;);
  format pctech pctmarge 6.2;
  title4  "Comparaison entre les marges finales dans l'échantillon"
          " (avec la pondération finale)";
  title5 " et les marges dans la population (marges du calage)";
run;

   /*  S'il y a des poids négatifs, la variable __WFIN doit etre rétablie  */

%if &poineg=1 %then
%do;

  proc datasets nolist;
    modify __calage;
    rename __wfin=__abspoi __zwfin=__wfin;

%end;

   /*  Edition des poids  */

%IF %upcase(&editpoi)=OUI %then
%do;

  PROC SUMMARY nway data=__CALAGE;
    class %do j=1 %to &jj; &&vc&j  %end;  %do l=1 %to &ll; &&vn&l  %end;
    %str(;);
    var  _f_;
    output out=__SOR mean=;
    title4 "Rapports de poids (pondérations finales / pondérations initiales)";
    title5 "pour chaque combinaison de valeurs des variables";

  PROC PRINT data=__SOR(drop=_type_) split="+";
    label _freq_=Effectif+combinaison
          _f_="Rapport+de poids";

%end;

   /*  Statistiques sur les poids  */

%if %upcase(&stat)=OUI %then
%do;

  PROC UNIVARIATE plot normal data=__CALAGE;
    var  _f_  __wfin;
    label _f_    = "Rapport de poids"
          __wfin = "Pondération finale";
    %if &ident ne %then
    %do;
      id &ident;
    %end;
    title4 "Statistiques sur les rapports de poids"
    " (= pondérations finales / pondérations initiales)";
    title5 "et sur les pondérations finales";
  run;
%end;

    /*********************************************
     *** Stockage des poids dans une table SAS ***
     *********************************************/

%if &poidsfin ne %then
%do;

  %let existe=non;

  %if %index(&datapoi,.) ne 0 %then    /* La table &DATAPOI contient un point */
  %do;
    %let base=%scan(&datapoi,1,.);
    %let table=%scan(&datapoi,2,.);
  %end;
  %else                         /* La table &DATAPOI ne contient pas de point */
  %do;
    %let base=work;
    %let table=&datapoi;
  %end;

  PROC CONTENTS noprint data=&base.._all_ out=__SOR(keep=memname);

  DATA _NULL_;
    set __SOR;
    if memname="%upcase(&table)" then call symput('existe','oui');
  run;

  %if &existe=oui and %upcase(&misajour)=OUI %then   /*   La table existe     */
  %do;                                               /*  et est mise à jour   */
    DATA &DATAPOI;
      merge &DATAPOI  __CALAGE(keep=__wfin &ident rename=(__wfin=&poidsfin));
      label &poidsfin="&labelpoi ";
  %end;

  %if &existe=non or (&existe=oui and %upcase(&misajour)=NON)
  %then                                    /*       La table n'existe pas     */
  %do;                                     /*  ou elle n'est pas mise à jour  */
    DATA &DATAPOI;
    set __CALAGE(keep=__wfin &ident rename=(__wfin=&poidsfin));
    label &poidsfin="&labelpoi ";
  %end;

  %if %upcase(&contpoi)=OUI %then
  %do;
    PROC CONTENTS data=&DATAPOI;
      title4 "Contenu de la table &datapoi contenant la nouvelle"
             " pondération &poidsfin";
  %end;
  run;
%end;

    /**************************************
     ***   Edition du bilan du calage   ***
     **************************************/

     /*   Pour avoir la date en français (ou en canadien français) ...   */

%let num  = %substr(&sysdate,1,2);
%let mois = %substr(&sysdate,3,3);
%let an   = %substr(&sysdate,6,2);
      %if &mois=JAN %then %let mois=JANVIER ;
%else %if &mois=FEB %then %let mois=FEVRIER ;
%else %if &mois=MAR %then %let mois=MARS;
%else %if &mois=APR %then %let mois=AVRIL ;
%else %if &mois=MAY %then %let mois=MAI ;
%else %if &mois=JUN %then %let mois=JUIN ;
%else %if &mois=JUL %then %let mois=JUILLET;
%else %if &mois=AUG %then %let mois=AOUT ;
%else %if &mois=SEP %then %let mois=SEPTEMBRE;
%else %if &mois=OCT %then %let mois=OCTOBRE;
%else %if &mois=NOV %then %let mois=NOVEMBRE;
%else %if &mois=DEC %then %let mois=DECEMBRE;

DATA _NULL_;
  file print;
  put //@20 "*********************";
  put   @20 "***     BILAN     ***";
  put   @20 "*********************";
  put @2 "*";

******************************* MODIF ********************************;

  put @2 "*   Date : &num &mois 20&an" @40 "Heure : &systime";

****************************** FIN MODIF ******************************;

  put @2 "*";
  put @2 "*   Table en entrée : %upcase(&data)";
  put @2 "*";
  put @2 "*   Nombre d'observations dans la table en entrée  : &effinit";
  put @2 "*   Nombre d'observations éliminées                : &effelim";
  put @2 "*   Nombre d'observations conservées               : &effech";
  put @2 "*";
  %if &pondgen=0 %then
  %do;
    put @2 "*   Variable de pondération : %upcase(&poids)";
  %end;
  %else
  %do;
    put @2 "*   Variable de pondération : taille de la population (&effpop)"
           " / nombre d'observations (&effech) (générée)";
  %end;
  %if &pondqk ne __UN and &pondqk ne %then %do;
    put @2 "*   Variable de pondération Qk : %upcase(&pondqk)";
  %end;
  put @2 "*";
  %if &jj>0 %then
  %do;
    put @2 "*   Nombre de variables catégorielles : &jj";
    put @2 "*   Liste des variables catégorielles et de leurs nombres de"
        " modalités :";
    put @8 %do j=1 %to &jj; "&&vc&j (&&m&j) " %end; @@;
    put / @2 "*   Taille de l'échantillon (pondéré) : &effpond";
    put   @2 "*   Taille de la population           : &effpop";
  put @2 "*";
  %end;
  %if &ll>0 %then
  %do;
    put @2 "*   Nombre de variables numériques : &ll";
    put @2 "*   Liste des variables numériques :";
    put @8 %do l=1 %to &ll; "&&vn&l " %end; @@;
    put / @2 "*";
  %end;
  put @2 "*   Méthode utilisée : "
        %if &m=1 %then %do; "linéaire" %end;
  %else %if &m=2 %then %do; "raking ratio" %end;
  %else %if &m=3 %then %do; "logit, borne inférieure = &lo,"
                            " borne supérieure = &up" %end;
  %else %if &m=4 %then %do; "linéaire tronquée,  borne inférieure = &lo,"
                            "  borne supérieure = &up" %end;
  %str(;);

      /*   Si tout s'est bien passé   */

  %if &arret=0 %then
  %do;
    %if &pb=0 %then
    %do;
      put @2 "*   Le calage a été réalisé en &niter itérations";
    %end;
    %else
    %do;
      put @2 "*   Le calage n'a pu etre réalisé qu'approximativement"
             " en &niter itérations";
    %end;
    %if &poineg=1 %then
    %do;
      put @2 "*   Il y a &npoineg poids négatifs";
    %end;
    %if &poidsfin ne %then
    %do;
      put @2 "*   Les poids ont été stockés dans la variable %upcase(&poidsfin)"
             " de la table %upcase(&datapoi)";
    %end;
  %end;

      /*   Si tout ne s'est pas bien passé   */

  %else
  %do;
    %if &maxit=1 %then
    %do;
      put @2 "*   Le nombre maximum d'itérations (&maxiter) a été atteint"
             " sans qu'il y ait convergence";
    %end;
    %else
    %do;
      put @2 "*   Le calage n'a pu etre réalisé";
    %end;
  %end;

%FIN : title3;

PROC DATASETS ddname=WORK nolist;
  delete  __burt  __calage __coeff __comp __datam __datama __lec1 __mar1 __mar11
          __mar3 __mar30 __mar31  __mar4  __mar5 __nmax __nomvar __phi __phi2
          __recap1 __recap2 __sor __tester __verif __effeli __marg__ __poids
          __ident __numcar __pondqk __mar12 __mary __vecp1 __vecp2 __vecp3;
  quit;
run;

options notes;

%mend calmar;
