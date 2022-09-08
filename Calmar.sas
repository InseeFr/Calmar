%MACRO CALMAR (
DATA      =       , /* Table SAS en entr�e                                    */
M         = 1     , /* M�thode utilis�e                                       */
POIDS     =       , /* Pond�ration initiale (poids de sondage Dk)             */
POIDSFIN  =       , /* Pond�ration finale   (poids de calage Wk)              */
PONDQK    = __UN  , /* Pond�ration Qk                                         */
LABELPOI  =       , /* Label de la pond�ration finale                         */
DATAPOI   =       , /* Table contenant la pond�ration finale                  */
MISAJOUR  =  OUI  , /* Mise � jour de la table &DATAPOI si elle existe d�j�   */
CONTPOI   =  OUI  , /* Contenu de la table pr�cedente                         */
LO        =       , /* Borne inf�rieure (m�thode logit ou lin�aire tronqu�e)  */
UP        =       , /* Borne sup�rieure (m�thode logit ou lin�aire tronqu�e)  */
EDITPOI   =  NON  , /* Edition des poids par combinaison de valeurs           */
STAT      =  OUI  , /* Statistiques sur les poids                             */
OBSELI    =  NON  , /* Stockage des observations �limin�es dans une table     */
IDENT     =       , /* Identifiant des observations                           */
DATAMAR   =       , /* Table SAS contenant les marges des variables de calage */
PCT       =  NON  , /* PCT = OUI si les marges sont en pourcentages           */
EFFPOP    =       , /* Effectif de la population (si PCT = OUI)               */
CONT      =  OUI  , /* Si CONT = OUI des controles sont effectu�s             */
MAXITER   =   15  , /* Nombre maximum d'it�rations                            */
NOTES     =  NON  , /* par d�faut : options NONOTES                           */
SEUIL     = 0.0001  /* Seuil pour le test d'arret                             */
)/store;
/*********************************************************************************/
/* La version du 10/09/2009 accepte plus de 999 variables de calage num�riques   */ 
/* (jusqu'� 9999).                                                               */ 
/*********************************************************************************/
/* La version du 21/12/2006 accepte plus de 999 modalit�s pour les variables     */
/* de calage cat�gorielles (jusqu'� 9999).                                       */ 
/*********************************************************************************/
/* La version du 11/08/2006 accepte plus de 99 variables de calage cat�gorielles */ 
/* et plus de 99 variables de calage num�riques (jusqu'� 999).                   */ 
/*********************************************************************************/

%put ;                                                                                          
%put ***************************************************; 
%put ** macro CALMAR : Version du 16/06/2015          **;
%put ** (pour calages sur 9999 variables num�riques)  **;
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
    ***  d'une table SAS &DATA � la macro-variable &NOMVAR         ***
    ***  (� condition que le param�tre &DATA ne contienne pas      ***
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
    ***  Edition des param�tres de la macro  ***
    ********************************************/

DATA _NULL_;
  file print;
  put //@28 "**********************************";
  put   @28 "***   Param�tres de la macro   ***";
  put   @28 "**********************************";
  put //@2 "Table en entr�e                     DATA      =  %upcase(&data)";
  put   @2 " Pond�ration initiale               POIDS     =  %upcase(&poids)";
  put   @2 " Pond�ration Qk                     PONDQK    =  %upcase(&pondqk)";
  put   @2 " Identifiant                        IDENT     =  %upcase(&ident)";
  put  /@2 "Table des marges                    DATAMAR   =  %upcase(&datamar)";
  put   @2 " Marges en pourcentages             PCT       =  %upcase(&pct)";
  put   @2 " Effectif de la population          EFFPOP    =  &effpop";
  put  /@2 "M�thode utilis�e                    M         =  &m";
  put   @2 " Borne inf�rieure                   LO        =  &lo";
  put   @2 " Borne sup�rieure                   UP        =  &up";
  put   @2 " Seuil d'arr�t                      SEUIL     =  &seuil";
  put   @2 " Nombre maximum d'it�rations        MAXITER   =  &maxiter";
  put  /@2 "Table contenant la pond. finale     DATAPOI   =  %upcase(&datapoi)";
  put  @2 " Mise � jour de la table DATAPOI    MISAJOUR  =  %upcase(&misajour)";
  put  @2 " Pond�ration finale                 POIDSFIN  =  %upcase(&poidsfin)";
  put   @2 " Label de la pond�ration finale     LABELPOI  =  &labelpoi";
  put   @2 " Contenu de la table DATAPOI        CONTPOI   =  %upcase(&contpoi)";
  put  /@2 "Edition des poids                   EDITPOI   =  %upcase(&editpoi)";
  put   @2 " Statistiques sur les poids         STAT      =  %upcase(&stat)";
  put  /@2 "Contr�les                           CONT      =  %upcase(&cont)";
  put   @2 "Table contenant les obs. �limin�es  OBSELI    =  %upcase(&obseli)";
  put   @2 "Notes SAS                           NOTES     =  %upcase(&notes)";

   /*************************************************************************
    ***  Controles lorsque l'on veut conserver les pond�rations finales   ***
    *************************************************************************/

%if %scan(&datapoi,1) ne %then
%do;

  %if &poidsfin = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 66*"*";
      put @2 "***   ERREUR : le param�tre POIDSFIN n'est pas renseign�"
          @65"***";
      put @2 "***            alors que le param�tre DATAPOI"
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
        put @2 "***   ERREUR : le param�tre DATAPOI vaut %upcase(&datapoi),"
               " mais"  @67 "***";
        put @2 "***            aucune base n'est allou�e au DDNAME"
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
        %put %str( ***   ERREUR : pas d%'acc�s en �criture sur la base ) ;
        %put %str( ***            allou�e au DDNAME %upcase(&base) )      ;
        %put %str( ***            sp�cifi� dans le param�tre DATAPOI ) ;
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

   /*   Fin des contr�les   */

   /*************************************************************************
    ***  Premiers controles (facultatifs) sur les param�tres de la macro  ***
    *************************************************************************/

%if %upcase(&cont)=OUI %then
%do;

   /*  Controles sur le param�tre DATA  */

  %if %scan(&data,1)= %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "**********************************************************";
      put   @2 "***   ERREUR : le param�tre DATA n'est pas renseign�   ***";
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
        put @2 "***            sp�cifi�e dans le param�tre DATA n'existe pas"
            @73 "***";
        put @2 74*"*";
      %goto FIN;
    %end;


  %end;

%end;

   /*   Fin des premiers contr�les facultatifs   */

   /*   La PROC CONTENTS sera utilis�e dans les contr�les facultatifs
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
    ***  Suite des controles (facultatifs) sur les param�tres de la macro  ***
    *************************************************************************/

%if %upcase(&cont)=OUI %then
%do;

   /*  Controles sur le param�tre DATAMAR  */

  %if %scan(&datamar,1)= %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "*************************************************************";
      put   @2 "***   ERREUR : le param�tre DATAMAR n'est pas renseign�   ***";
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
      put   @2 "***            sp�cifi�e dans le param�tre DATAMAR n'existe pas"
            @73 "***";
      put   @2 74*"*";
      %goto FIN;
    %end;
  %end;

   /*  Controles sur le param�tre M  */

  %if &m ne 1 and &m ne 2 and &m ne 3 and &m ne 4 %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***************************************************";
      put   @2 "***   ERREUR : la valeur du param�tre M (&m)    ***";
      put   @2 "***            est diff�rente de 1, 2, 3 et 4   ***";
      put   @2 "***************************************************";
    %goto FIN;
  %end;

  %if (&m=3 or &m=4) and %scan(&lo,1) = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***********************************************************";
      put   @2 "***   ERREUR : le param�tre M vaut (&m)                 ***";
      put   @2 "***            et le param�tre LO n'est pas renseign�   ***";
      put   @2 "***********************************************************";
    %goto FIN;
  %end;

  %if (&m=3 or &m=4) and %scan(&up,1) = %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "***********************************************************";
      put   @2 "***   ERREUR : le param�tre M vaut (&m)                 ***";
      put   @2 "***            et le param�tre UP n'est pas renseign�   ***";
      put   @2 "***********************************************************";
    %goto FIN;
  %end;

   /*  Controle sur le param�tre EFFPOP  */

  %if &effpop = and %upcase(&pct)=OUI %then
  %do;
    DATA _NULL_;
      file print;
      put //@2 "*************************************************************";
      put   @2 "***   ERREUR : le param�tre EFFPOP n'est pas renseign�    ***";
      put   @2 "***            alors que les marges sont donn�es en       ***";
      put   @2 "***            pourcentages (le param�tre PCT vaut OUI)   ***";
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
          put @2 "***   ERREUR : la variable %upcase(&poids) sp�cifi�e dans le"
              @73 "***";
          put @2 "***            param�tre POIDS ne figure pas dans"  @73 "***";
          put @2 "***            la table %upcase(&data)" @73 "***";
          put @2 74*"*";
      %goto FIN;
    %end;

    %else %if &poidscar=2 %then
    %do;
      DATA _NULL_;
        file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la variable %upcase(&poids) sp�cifi�e dans le"
               " param�tre POIDS" @73 "***";
        put @2 "***            et figurant dans la"                 @73 "***";
        put @2 "***            table %upcase(&data)"                @73 "***";
        put @2 "***            n'est pas num�rique"                 @73 "***";
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
          put @2 "***   ERREUR : la variable %upcase(&pondqk) sp�cifi�e dans le"
              @73 "***";
          put @2 "***            param�tre PONDQK ne figure pas dans" @73 "***";
          put @2 "***            la table %upcase(&data)" @73 "***";
          put @2 74*"*";
      %goto FIN;
    %end;

    %else %if &pondqcar=2 %then
    %do;
      DATA _NULL_;
        file print;
        put //@2 74*"*";
        put @2 "***   ERREUR : la variable %upcase(&pondqk) sp�cifi�e dans"
               " le param�tre PONDQK"  @73 "***";
        put @2 "***            et figurant dans la"                 @73 "***";
        put @2 "***            table %upcase(&data)"                @73 "***";
        put @2 "***            n'est pas num�rique"                 @73 "***";
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
          put @2 "***   ERREUR : la variable %upcase(&ident) sp�cifi�e dans le"
              @73 "***";
          put @2 "***            param�tre IDENT ne figure pas dans"  @73 "***";
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
        put @2 "***            sp�cifi�e dans le param�tre DATAMAR"   @73 "***";
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
      put @2 "***            sp�cifi�e dans le param�tre DATAMAR" @73 "***";
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
      put @2 "***            n'est pas num�rique"                 @73 "***";
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
      title6 "sp�cifi�e dans le param�tre DATAMAR, n'existent pas";
      title7 "dans la table %upcase(&data)";
      title8 "sp�cifi�e dans le param�tre DATA";
    run;
    %goto FIN;
  %end;

  %else %do;
    %nobs(__NUMCAR,numcar)
    %if &numcar>0 %then
    %do;
      PROC PRINT data=__NUMCAR(drop=type n);
        id var;
        title4 "ERREUR : les variables suivantes sont d�clar�es comme"
               " num�riques (N=0)";
        title5 "de la table %upcase(&datamar)";
        title6 "sp�cifi�e dans le param�tre DATAMAR,";
        title7 "alors que ce sont des variables caract�res";
        title8 "dans la table %upcase(&data)";
        title9 "sp�cifi�e dans le param�tre DATA";
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

   /*  D�termination du nombre maximum de modalit�s  */

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
      put @2 "***   ERREUR : une (au moins) des variables MAR1 � MAR&nmax"
             " ne figure pas"                                         @73 "***";
      put @2 "***            dans la table %upcase(&datamar)"         @73 "***";
      put @2 "***            sp�cifi�e dans le param�tre DATAMAR"     @73 "***";
      put @2 "***            (&nmax est le nombre maximum de modalit�s sp�cifi�"
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
      put @2 "***   ERREUR : parmi les variables MAR1 � MAR&nmax figurant dans"
          @73 "***";
      put @2 "***            la table %upcase(&datamar)"              @73 "***";
      put @2 "***            &marcar ne sont pas num�riques"          @73 "***";
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
  type="C";                               /*  variable cat�gorielle  */
  if n=0 then type="N";                   /*  variable num�rique     */
  tot=sum(of mar1-mar&nmax);

   /*  Si les marges des variables cat�gorielles sont donn�es en effectifs  */

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

   /*  Si les marges des variables cat�gorielles sont donn�es en pourcentages */

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

   /*  Si CONT vaut OUI, des controles sont effectu�s  */

%if %upcase(&cont)=OUI %then
%do;

  if type="C" then           /*  les variables MARn sont-elles renseign�es ?  */
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
      title4 "ERREUR : pour au moins une variable cat�gorielle, les marges"
             " MAR1 � MARN,";
      title5 " o� N est le nombre de modalit�s, ne sont pas"
            " toutes renseign�es";
    run;
  %end;


  %if &erreur3=1 %then
  %do;
    PROC PRINT data=__MAR1(where=(type="N"));
      id var;
      var n mar1-mar&nmax erreur;
      title4 "ERREUR : pour au moins une variable num�rique, la marge"
             " MAR1 n'est pas renseign�e";
    run;
  %end;

  %if &erreur1=1 or &erreur3=1 %then %goto FIN;

   /*  V�rification sur les totaux des marges des variables cat�gorielles  */

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
      TITLE4  "ERREUR : les totaux des marges des variables cat�gorielles "
            "ne sont pas tous �gaux";
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
          TITLE4  "ERREUR : les totaux des marges des variables cat�gorielles "
                "ne sont pas �gaux � 100";
        run;
        %goto FIN;
      %end;
    %end;

  %end;

%end;

   /*  Fin des controles  */

   /**********************************************************************
    ***  Construction de la table __MAR3 et des macros-variables       ***
    ***  contenant les noms des variables et les nombres de modalit�s  ***
    **********************************************************************/

PROC SORT data=__MAR1;                   /*  tri par type de variable  */
  by type var;

PROC FREQ data=__MAR1;
  tables type/ out=__LEC1 noprint;

DATA _NULL_;
  set __LEC1;
  %let jj=0;          /*  jj est le nombre de variables cat�gorielles  */
  %let ll=0;          /*  ll est le nombre de variables num�riques     */
  if type="C" then call symput('jj',left(put(count,9.)));
  if type="N" then call symput('ll',left(put(count,9.)));
run;

DATA _NULL_;
  merge __MAR1(where=(type="C") in=in1) __NOMVAR(rename=(type=typesas));
  by var;
  if in1;
  retain k 0;
  k=k+1;
/* Modification du 11/8/2006 pour accepter plus de 99 var. cat�gorielles      */
/*j=put(k,2.);                                                                */
  j=put(k,3.);
  if k=1 then nn=n;
  else nn=n-1;
  mac="vc"!!left(j); /* Les VCj contiendront les noms des var. cat�gorielles  */
  mad="m"!!left(j);  /* Les Mj (resp.Nj) contiendront les nombres de modalit�s*/
  mae="n"!!left(j);  /*(resp. -1, sauf la 1�re) des variables cat�gorielles   */
  maf="t"!!left(j);  /* Les Tj valent 1 pour une var.num., 2 pour une var.car.*/
  call symput(mac,trim(var));

/*****************************************************/
/* Modification du 21/12/2006 pour prendre en compte */
/* les variables ayant plus de 999 modalit�s         */
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
/* Modification du 11/8/2006 pour accepter plus de 99 var. num�riques         */
/*j=put(_n_,2.);                                                              */
/* Modification du 10/9/2009 pour accepter plus de 999 var. num�riques        */
/*j=put(_n_,3.);                                                              */
  j=put(_n_,4.);
  mac="vn"!!left(j);   /* Les VNj contiendront les noms des var. num�riques   */
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

  /*  Calcul de la taille de la taille de la population en pr�sence
      de variables cat�gorielles                                     */

%if &vc1 ne and %upcase(&pct) ne OUI %then
%do;

  DATA _NULL_;
    set __MAR1(keep=tot obs=1);
    call symput("effpop",left(put(tot,10.)));
  run;

%end;

  /*  Calcul de la taille de l'�chantillon si la variable de
      pond�ration initiale &POIDS est manquante                */

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
      put @2 "***            sp�cifi�e dans le param�tre DATA a 0 observation"
          @73 "***";
      put @2 "***            non �limin�e" @73 "***";
      put @2 74*"*";
    %goto FIN;
  %end;

%let pondgen=1;

%end;

   /*  Un nouveau controle ... sur le param�tre POIDS cette fois-ci  */

%if %upcase(&cont)=OUI %then
%do;
  %if &poids = and &vc1 = %then
  %do;
  DATA _NULL_;
    file print;
   put //@2 "*****************************************************************";
    put @2 "***   ERREUR : le param�tre POIDS n'est pas renseign� alors   ***";
    put @2 "***            qu'il n'y a pas de variable cat�gorielle       ***";
    put @2 "*****************************************************************";
    %goto FIN;
  %end;
%end;

   /**************************************************
    ***  Cr�ation de la table de travail __CALAGE  ***
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

 /*  Cr�ation de variables disjonctives � partir des variables cat�gorielles  */

  %do j=1 %to &jj;
    %if &&t&j=1 %then                    /* cas de variables num�riques-SAS  */
      %do i=1 %to &&m&j;
        y&j._&i=(&&vc&j=&i);
      %end;
    %if &&t&j=2 %then                    /* cas de variables caract�res-SAS  */
      %do;
        %if &&m&j<10 %then                    /*  moins de 10 modalit�s  */
        %do i=1 %to &&m&j;
          y&j._&i=(&&vc&j="&i");
        %end;
        %else %if &&m&j<100 %then             /*  de 10 � 99 modalit�s  */
        %do;
          %do i=1 %to 9;
            y&j._&i=(&&vc&j="0&i");
          %end;
          %do i=10 %to &&m&j;
            y&j._&i=(&&vc&j="&i");
          %end;
        %end;
        %else %if &&m&j<1000 %then            /*  de 100 � 999 modalit�s  */
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
		/* les variables ayant plus de 999 modalit�s         */
		/*****************************************************/
		%else          						  /*  de 1000 � 9999 modalit�s  */
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

   /*   Calcul de l'effectif (non pond�r�) de l'�chantillon)   */

%nobs(__calage,effinit)

%if &effinit=0 %then
%do;
  DATA _NULL_;
    file print;
    put //@2 74*"*";
    put @2 "***   ERREUR : la table %upcase(&DATA)" @73 "***";
    put @2 "***            sp�cifi�e dans le param�tre DATA a 0 observation"
        @73 "***";
    put @2 74*"*";
  %goto FIN;
%end;

   /*   Calcul des nombres d'observations �limin�es et conserv�es   */

%if &pondgen=1 %then       /*  Nombre d'observations conserv�es d�j� calcul�  */
%do;
  %let effelim=%eval(&effinit-&effech);
%end;

%else %do;                  /*  Nombre d'observations conserv�es non calcul�  */

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
      put @2 "***            sp�cifi�e dans le param�tre DATA a &effinit"
             " observations..." @73 "***";
      put @2 "***            mais elles sont toutes �limin�es !" @73 "***";
      put @2 "***" @73 "***";
      put @2 "***   Une observation de la table en entr�e est �limin�e d�s que"
          " :" @73 "***";
      put @2 "***   - elle a une valeur manquante sur l'une des variables du"
          " calage" @73 "***";
      put @2 "***   - elle a une valeur manquante, n�gative ou nulle sur l'une"
          @73 "***";
      put @2 "***     des variables de pond�ration." @73 "***";
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
    ***  Impression des marges (population et �chantillon)  ***
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

   /*  Controle sur les effectifs des modalit�s des variables cat�gorielles   */

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
            modalite="Modalit�"
            echant="Marge*�chantillon"
            pctech="Pourcentage*�chantillon"
            total2="Effectif*cumul�"
            effpond2="Effectif*�chantillon"
            erreur="Erreur";
      var modalite echant pctech total2 effpond2 erreur;
      title4  "ERREUR : pour au moins une variable cat�gorielle, l'effectif"
              " cumul� (pond�r�) des modalit�s n'est pas �gal";
      title5  "� l'effectif (pond�r�) de l'�chantillon";

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
    title4 "Les effectifs (pond�r�s) des modalit�s des variables cat�gorielles"
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
        modalite="Modalit�*ou variable"
        echant="Marge*�chantillon"
        pctech="Pourcentage*�chantillon"
        marge="Marge*population"
        pctmarge="Pourcentage*population"
        err="Effectif*nul";
  var modalite echant marge pctech pctmarge
  %if &pb1=1 %then %do; err %end;
  %str(;);
  format pctech pctmarge 6.2;
  title4  "Comparaison entre les marges tir�es de l'�chantillon (avec la"
          " pond�ration initiale)";
  title5  "et les marges dans la population (marges du calage)";
  %if &pb1=1 %then
  %do;
    title6 "ERREUR : l'effectif d'une modalit� (au moins) d'une variable"
           " cat�gorielle est nul";
    title7 "alors que la marge correspondante est non nulle : le calage est "
           "impossible";
  %end;
run;
title4;

%if &pb1=1 %then %goto FIN;



   /***************************************************************
    **** Cr�ation de la table  __COEFF et des macros variables  ***
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

 %if &m=1 %then %do; title3 "M�thode : lin�aire " %str(;); %end;
 %if &m=2 %then %do; title3 "M�thode : raking ratio" %str(;); %end;
 %if &m=3 %then %do; title3 "M�thode : logit, inf=&lo, sup=&up" %str(;); %end;
 %if &m=4 %then %do; title3 "M�thode : lin�aire tronqu�e, inf=&lo, sup=&up"
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
    put   @10 "***   Le nombre maximum d'it�rations (&maxiter) a �t� atteint"
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
  %put ***   Le calage ne peut etre r�alis�. Pour rendre le calage      ***;
  %put ***   possible, vous pouvez :                                    ***;
  %put ***                                                              ***;
  %if &m=3 or &m=4 %then
  %do;
  %put ***   - diminuer la valeur de LO                                 ***;
  %put ***   - augmenter la valeur de UP                                ***;
  %end;
  %if &m=2 or &m=3 or &m=4 %then
  %do;
  %put ***   - utiliser la m�thode lin�aire (M=1)                       ***;
  %end;
  %if &vc1 ne %then
  %do;
  %put ***   - op�rer des regroupements de modalit�s de variables       ***;
  %put ***     cat�gorielles                                            ***;
    %if &effpond ne &effpop %then
    %do;
  %put ***   - changer la variable de pond�ration initiale, car         ***;

  %put ***     l'effectif pond�r� de l' �chantillon vaut &effpond ;
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

  if ncol(inverse)=0 then            /*  Cas o� PHIPRIM n'est pas inversible  */
  do;
    call symput('pbiml','1');
  end;

  else                               /*  Cas o� PHIPRIM est inversible  */
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

   /*   Cas o� PHIPRIM n'est pas inversible : l'algorithme s'arrete   */

%if &pbiml=1 and &niter=1 %then              /*  Si c'est la 1�re it�ration   */
%do;
  DATA _NULL_;
    file print;
    put //@10 "******************************************************";
    put   @10 "***   Les variables analys�es sont colin�aires :   ***";
    put   @10 "***   le calage ne peut etre r�alis�               ***";
    put   @10 "******************************************************";

                                      /*   Recherche des liaisons lin�aires   */

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
    title3 "Coefficients de la (ou des) combinaison(s) lin�aire(s)"
           " nulle des variables du calage";
    title4 "(une variable de nom WXY 2 d�signe la variables indicatrice"
           " associ�e � la modalit� 2 de la variable cat�gorielle WXY)";
    run;

    %goto FIN;
%end;

%if &pbiml=1 and &niter>1 %then       /*  Si ce n'est pas la 1�re it�ration   */
%do;
  DATA _NULL_;
    file print;
 put //@5 "*******************************************************************";
 put @5   "***   Le calage ne peut etre r�alis�. Pour rendre le calage     ***";
 put @5   "***   possible, vous pouvez :                                   ***";
 put @5   "***                                                             ***";
 %if &m=3 or &m=4 %then
 %do;
 put @5   "***   - diminuer la valeur de LO                                ***";
 put @5   "***   - augmenter la valeur de UP                               ***";
 %end;
 %if &m=2 or &m=3 or &m=4 %then
 %do;
 put @5   "***   - utiliser la m�thode lin�aire (M=1)                      ***";
 %end;
 %if &vc1 ne %then
 %do;
 put @5   "***   - op�rer des regroupements de modalit�s de variables      ***";
 put @5   "***     cat�gorielles                                           ***";
 %if &effpond ne &effpop %then
 %do;
 put @5   "***   - changer la variable de pond�ration initiale, car        ***";
 put @5   "***     l'effectif pond�r� de l'�chantillon vaut &effpond" @69 "***";
 put @5   "***     alors que l'effectif de la population vaut &effpop"
     @69  "***";
 %end;
 %end;
 put @5   "*******************************************************************";
    call symput('arret','1');
    %goto ARRET;
%end;

   /*  Construction de la table contenant les r�capitulatifs des it�rations  */

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
    ***  Mise � jour de la table __CALAGE  ***
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

   /*  Cas o� il peut exister des poids n�gatifs  */

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

   /*  Calcul du crit�re d'arret  */

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
  put  @10 "***   Valeur du crit�re d'arr�t � l'it�ration &NITER : &maxdif"
       @70 "***";
  put  @10 "***************************************************************";
  put /;

%if not (&m=1 or (&m=3 and %index(&lo,-) ne 0) or (&m=4 and %index(&lo,-) ne 0))
and &poineg=1 %then
%do;
  DATA _NULL_;
    file print;
 put //@5 "*******************************************************************";
 put @5   "***   Le calage ne peut etre r�alis�. Pour rendre le calage     ***";
 put @5   "***   possible, vous pouvez :                                   ***";
 put @5   "***                                                             ***";
 %if &m=3 or &m=4 %then
 %do;
 put @5   "***   - diminuer la valeur de LO                                ***";
 put @5   "***   - augmenter la valeur de UP                               ***";
 %end;
 %if &m=2 or &m=3 or &m=4 %then
 %do;
 put @5   "***   - utiliser la m�thode lin�aire (M=1)                      ***";
 %end;
 %if &vc1 ne %then
 %do;
 put @5   "***   - op�rer des regroupements de modalit�s de variables      ***";
 put @5   "***     cat�gorielles                                           ***";
 %if &effpond ne &effpop %then
 %do;
 put @5   "***   - changer la variable de pond�ration initiale, car        ***";
 put @5   "***     l'effectif pond�r� de l'�chantillon vaut &effpond" @69 "***";
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
    ***  Les �ditions  ***
    **********************/

%ARRET : ;

   /*  Tableaux r�capitulatifs de l'algorithme  */

DATA __RECAP1;
  set __RECAP1 end=fin;
  iter=_n_;
  %if &poineg=1 %then           /*  R�cup�ration du nombre de poids n�gatifs  */
  %do;
    if fin then
    do;
      call symput('npoineg',left(put(poidsneg,10.)));
    end;
  %end;

PROC PRINT data=__RECAP1 split="*";
 id iter;
 var test poidsneg;
 label test="Crit�re*d'arr�t"
       poidsneg="Poids*n�gatifs"
       iter="It�ration";
 title4 "Premier tableau r�capitulatif de l'algorithme :";
 title5 "la valeur du crit�re d'arr�t et le nombre de poids n�gatifs"
         " apr�s chaque it�ration";

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
         modalite="Modalit�";
   title4 "Deuxi�me tableau r�capitulatif de l'algorithme :";
   title5 "les coefficients du vecteur lambda de multiplicateurs de Lagrange"
          " apr�s chaque it�ration";
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
    put   @10 "***   ATTENTION : l'algorithme a converg�, mais le calage   ***";
    put   @10 "***               n'est pas parfaitement r�alis�            ***";
    put   @10 "***************************************************************";
%end;

PROC PRINT data=__MAR5 split="*";
  by var1 notsorted;
  id var1;
  label var1="Variable"
        modalite="Modalit�*ou variable"
        echant="Marge*�chantillon"
        pctech="Pourcentage*�chantillon"
        marge="Marge*population"
        erreur="Erreur"
        pctmarge="Pourcentage*population";
  var modalite echant marge pctech pctmarge
  %if &pb=1 %then %do; erreur %end;
  %str(;);
  format pctech pctmarge 6.2;
  title4  "Comparaison entre les marges finales dans l'�chantillon"
          " (avec la pond�ration finale)";
  title5 " et les marges dans la population (marges du calage)";
run;

   /*  S'il y a des poids n�gatifs, la variable __WFIN doit etre r�tablie  */

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
    title4 "Rapports de poids (pond�rations finales / pond�rations initiales)";
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
          __wfin = "Pond�ration finale";
    %if &ident ne %then
    %do;
      id &ident;
    %end;
    title4 "Statistiques sur les rapports de poids"
    " (= pond�rations finales / pond�rations initiales)";
    title5 "et sur les pond�rations finales";
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
  %do;                                               /*  et est mise � jour   */
    DATA &DATAPOI;
      merge &DATAPOI  __CALAGE(keep=__wfin &ident rename=(__wfin=&poidsfin));
      label &poidsfin="&labelpoi ";
  %end;

  %if &existe=non or (&existe=oui and %upcase(&misajour)=NON)
  %then                                    /*       La table n'existe pas     */
  %do;                                     /*  ou elle n'est pas mise � jour  */
    DATA &DATAPOI;
    set __CALAGE(keep=__wfin &ident rename=(__wfin=&poidsfin));
    label &poidsfin="&labelpoi ";
  %end;

  %if %upcase(&contpoi)=OUI %then
  %do;
    PROC CONTENTS data=&DATAPOI;
      title4 "Contenu de la table &datapoi contenant la nouvelle"
             " pond�ration &poidsfin";
  %end;
  run;
%end;

    /**************************************
     ***   Edition du bilan du calage   ***
     **************************************/

     /*   Pour avoir la date en fran�ais (ou en canadien fran�ais) ...   */

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
  put @2 "*   Table en entr�e : %upcase(&data)";
  put @2 "*";
  put @2 "*   Nombre d'observations dans la table en entr�e  : &effinit";
  put @2 "*   Nombre d'observations �limin�es                : &effelim";
  put @2 "*   Nombre d'observations conserv�es               : &effech";
  put @2 "*";
  %if &pondgen=0 %then
  %do;
    put @2 "*   Variable de pond�ration : %upcase(&poids)";
  %end;
  %else
  %do;
    put @2 "*   Variable de pond�ration : taille de la population (&effpop)"
           " / nombre d'observations (&effech) (g�n�r�e)";
  %end;
  %if &pondqk ne __UN and &pondqk ne %then %do;
    put @2 "*   Variable de pond�ration Qk : %upcase(&pondqk)";
  %end;
  put @2 "*";
  %if &jj>0 %then
  %do;
    put @2 "*   Nombre de variables cat�gorielles : &jj";
    put @2 "*   Liste des variables cat�gorielles et de leurs nombres de"
        " modalit�s :";
    put @8 %do j=1 %to &jj; "&&vc&j (&&m&j) " %end; @@;
    put / @2 "*   Taille de l'�chantillon (pond�r�) : &effpond";
    put   @2 "*   Taille de la population           : &effpop";
  put @2 "*";
  %end;
  %if &ll>0 %then
  %do;
    put @2 "*   Nombre de variables num�riques : &ll";
    put @2 "*   Liste des variables num�riques :";
    put @8 %do l=1 %to &ll; "&&vn&l " %end; @@;
    put / @2 "*";
  %end;
  put @2 "*   M�thode utilis�e : "
        %if &m=1 %then %do; "lin�aire" %end;
  %else %if &m=2 %then %do; "raking ratio" %end;
  %else %if &m=3 %then %do; "logit, borne inf�rieure = &lo,"
                            " borne sup�rieure = &up" %end;
  %else %if &m=4 %then %do; "lin�aire tronqu�e,  borne inf�rieure = &lo,"
                            "  borne sup�rieure = &up" %end;
  %str(;);

      /*   Si tout s'est bien pass�   */

  %if &arret=0 %then
  %do;
    %if &pb=0 %then
    %do;
      put @2 "*   Le calage a �t� r�alis� en &niter it�rations";
    %end;
    %else
    %do;
      put @2 "*   Le calage n'a pu etre r�alis� qu'approximativement"
             " en &niter it�rations";
    %end;
    %if &poineg=1 %then
    %do;
      put @2 "*   Il y a &npoineg poids n�gatifs";
    %end;
    %if &poidsfin ne %then
    %do;
      put @2 "*   Les poids ont �t� stock�s dans la variable %upcase(&poidsfin)"
             " de la table %upcase(&datapoi)";
    %end;
  %end;

      /*   Si tout ne s'est pas bien pass�   */

  %else
  %do;
    %if &maxit=1 %then
    %do;
      put @2 "*   Le nombre maximum d'it�rations (&maxiter) a �t� atteint"
             " sans qu'il y ait convergence";
    %end;
    %else
    %do;
      put @2 "*   Le calage n'a pu etre r�alis�";
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
