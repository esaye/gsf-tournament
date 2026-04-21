#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


MODULE = TSH::Pair		PACKAGE = TSH::Pair		

AV *
Resolve(playersp)
  SV * playersp
  INIT:
    int i;
    int nplayers;
    AV *pairings;
    int *prefs;
    AV *players;
    /* players is not a reference */
    if (!SvROK(playersp)) { XSRETURN_UNDEF; }
    /* players is not a reference to an array */
    players = (AV *) SvRV(playersp);
    if (SvTYPE(players) != SVt_PVAV) { XSRETURN_UNDEF; }
    /* count players */
    nplayers = av_len(players) + 1;
    /* allocate return vector */
    pairings = (AV *) sv_2mortal((SV *)newAV());
    /* allocate working copies of preference lists */
    Newz(1, prefs, nplayers * nplayers, int);
  CODE:
    av_push(pairings, newSVuv((UV) nplayers));
    Safefree(prefs);
    RETVAL = pairings;
  OUTPUT:
    RETVAL
