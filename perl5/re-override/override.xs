/* See NOTES for an overview on re::override internals. */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "embed.h"

#define re_override_debug(f, s)
#define re_override_debug1(f, s, x)
#define re_override_debug2(f, s, x, y)
#define re_override_debug3(f, s, x, y, z)

#include <regcomp.h>
/* for the struct pointed to by substrs :( */

#define RECOGNITION_FLAG 0xfdfcd84a
#define CONTAINS_RECOGNITION_FLAG(r) \
  (r->offsets[0] >= 1 && \
   r->offsets[1] == RECOGNITION_FLAG)

static regexec_t previous_exec_hook = NULL;

I32 regexp_exechook_hook (pTHX_ regexp* r, char* stringarg, char* strend,
			  char* strbeg, I32 minend, SV* screamer,
			  void* data, U32 flags)
{
  if(!CONTAINS_RECOGNITION_FLAG(r)) {
    return previous_exec_hook(aTHX_ r,stringarg,strend,strbeg,
			      minend,screamer,data,flags);
  }
  else {
    dSP;
    int pops_left;
    SV* perl_callback;
    I32 ret;
    IV matched;
    U32 start;
    int newstr;

    if(stringarg-strbeg < 0) {re_override_debug(stderr,"assert-082eedc532\n");exit(0);}
    start = stringarg-strbeg;

    re_override_debug(stderr,"regexp_exechook_hook\n");
    re_override_debug3(stderr," strbeg=%lu\n strarg=%lu\n strend=%lu\n",strbeg,stringarg,strend);
    re_override_debug1(stderr," flags=%lu\n",flags);
    re_override_debug1(stderr," start=%lu\n",start);
/*
    re_override_debug(stderr," minend=%ld pos=%ld\n",minend,PL_reg_ganch);
*/

    perl_callback = r->substrs->data[0].substr;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(strbeg,strend-strbeg)));
    XPUSHs(sv_2mortal(newSVuv(flags)));
    XPUSHs(sv_2mortal(newSVuv(start)));
    XPUSHs(sv_2mortal(newSViv(minend)));
    XPUSHs(sv_2mortal(newSVuv((unsigned long)r)));
    PUTBACK;

    re_override_debug2(stderr,"exec hook r=%lu callback SV*=%lu\n",(unsigned long)r,(unsigned long)perl_callback);
    ret = call_sv(perl_callback, G_ARRAY);
    SPAGAIN;
    re_override_debug(stderr,"exec hook survived.\n");
    if(ret < 1) {
	re_override_debug(stderr,"regexp_hook_exec failed - didnt return anything\n"); exit(0);
    }
    pops_left = ret;
    matched = POPi; pops_left--;

    { /* fail captures */
      int i;
      for(i=0;i<=r->nparens;i++) {
	r->startp[i] = -1;
	r->endp[i] = -1;
      }
      r->lastparen = r->lastcloseparen = 0;
    }

/*
    newstr = (r->sublen != strend-strbeg
              || !strnEQ(r->subbeg,strbeg,r->sublen));
    newstr = matched;
*/
    newstr = 1; /*1-leak?,(0 only for isolated devtest)*/
    if(newstr) {
      if(RX_MATCH_COPIED(r) && 0) {
        Safefree(r->subbeg); /* fails tests in split.t */
      }
      r->sublen = strend-strbeg;
      r->subbeg = savepvn(strbeg,r->sublen);
      RX_MATCH_COPIED_set(r,1);
    }

    if(matched) {
      SV* lp;
      SV* lcp; 
      int cap_idx = 0; /* number of caps is nparens+1 */
      if(ret < 1+2+2 || ret > 1+2+2 + 2 * r->nparens) {
        re_override_debug(stderr,"regexp_hook_exec failed - paren info broken\n"); exit(0);
      }
      lp = POPs; pops_left--;
      lcp = POPs; pops_left--;
      for(cap_idx=0; cap_idx <= r->nparens && pops_left;cap_idx++) {
        SV* v;
        IV vi;

        v = POPs; pops_left--;
        vi = SvOK(v) ? SvIV(v) : -1;
        r->startp[cap_idx] = vi;

        v = POPs; pops_left--;
        vi = SvOK(v) ? SvIV(v) : -1;
        r->endp[cap_idx] = vi;
      }
      for(;pops_left;) {
        POPs; pops_left--;
      }

      r->lastparen = SvOK(lp) ? SvIV(lp) : r->nparens;
      r->lastcloseparen = SvOK(lcp) ? SvIV(lcp) : r->nparens;
    }
    else {
      while(pops_left--) {
        POPs;
      }
    }
    PUTBACK;

    re_override_debug(stderr,"done.\n");
    return matched ? 1 : 0;
  }
}

void regexp_exechook_insert ()
{
  if(previous_exec_hook != NULL) { croak("can't install twice"); }
  previous_exec_hook = PL_regexecp;
  PL_regexecp = &regexp_exechook_hook;
}


/*
 * regexp struct setup
 */

static void regexp_setup(pTHX_ regexp* r, SV* pat, U32 nparens, SV* callback)
{
    I32 len;
    int i;

    re_override_debug(stderr,"regexp_setup ");
    Safefree(r->precomp);
    r->prelen = SvLEN(pat);
    if(r->prelen <0){ re_override_debug(stderr,"zoork!\n");exit(0);}
    r->precomp = savesvpv(pat);
    
    r->nparens = nparens;
    
    Renew(r->startp, nparens+1, I32);
    Renew(r->endp, nparens+1, I32);
    
    len = 1;
    if(r->offsets[0] < len) {
      Renew(r->offsets, 2*len+1, U32);
      r->offsets[0] = len;
    }

    r->offsets[1] = RECOGNITION_FLAG;

    /*XXX should SvREFCNT_dec current value */
    r->substrs->data[0].substr = SvREFCNT_inc(callback);

    /* Try to scare off the rest of perl */
    r->minlen = 0;
    r->reganch = 0;
    /* Make sure environment is set up (also helps scare off perl) */
    r->reganch |= ROPT_GPOS_SEEN | ROPT_LOOKBEHIND_SEEN | ROPT_EVAL_SEEN;
    r->reganch |= ROPT_CANY_SEEN | ROPT_SANY_SEEN;
    /* But not ROPT_CHECK_ALL */

    
    /* XXX Does regcomp.c zero any of the match fields? */
}

/*
 * regexp_compile
 */

static regcomp_t previous_comp_hook = NULL;

regexp* hook_regcompp (pTHX_ char* exp, char* xend, PMOP* pm)
{
  SV* handler = NULL;

  re_override_debug1(stderr,"hook_regcompp in %lx\n",(unsigned long)exp);

  /* An attempt to use %^H for lexical scoping.
     Unfortunately, it seems that while it has lexical extent,
     it has dynamic scope. Ie, subs called see its affect too, yes? */
  if(handler == NULL) {
    const char hint_key[] = "regcompp";
    SV** phandler;      
    HV* hints;
    hints = get_hv("\b",0);
    if(hints != NULL) {
      phandler = hv_fetch(hints, hint_key, strlen(hint_key), 0);
      if(phandler != NULL) {
        handler = *phandler;
        re_override_debug1(stderr,"hook_regcompp lexical...%lx\n",(unsigned long)handler);
/*	call_sv(handler,G_DISCARD|G_EVAL);
        re_override_debug(stderr,"can survive %lx %lx\n",(unsigned long)exp,(unsigned long)handler);
*/
      }
    }
  }
  /* Dynamically scoped overriding, mainly for selection of
     p5re-equivalent implementations, rather than for semantics. */
  if(handler == NULL) {
    SV* sv;
    sv = get_sv("Regexp::Override::regcompp",0);
    if(sv != NULL && SvTRUE(sv)) {
      re_override_debug(stderr,"hook_regcompp dynamic...\n");
      handler = sv;
    }
  }  
  /* Example of a perhaps more promising approach to lexical scoping */
  if(handler == NULL) {
    SV* sv;
    sv = eval_pv("$regexp_override_regcompp",0);
    if(sv != NULL && SvTRUE(sv)) {
      re_override_debug(stderr,"regexp_override_regcompp...\n");
      handler = sv;
    }
  }  
  /* If no handlers, or handler is an int, then hand off */
  if(handler == NULL || SvIOK(handler)) {
    re_override_debug(stderr,"hook_regcompp punt.\n");
    return previous_comp_hook(aTHX_ exp,xend,pm);
  }
  {
    dSP;
    char *nulpat;
    regexp* r;
    I32 ret;
    I32 api;

    nulpat = savepv(""); /*XXX - can be constant? */
    r = Perl_pregcomp(aTHX_ nulpat,nulpat,pm);
    /*XXX - can free nulpat now? */

/*    re_override_debug(stderr,"exp =%lu\nxend=%lu\n",(unsigned long)exp,(unsigned long)xend);*/
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpvn(exp,xend-exp)));
    XPUSHs(sv_2mortal(newSVuv((unsigned long)r)));
    PUTBACK;
  HANDLER_CALL:
/*    re_override_debug(stderr,"calling out...\n");*/
    ret = call_sv(handler, G_ARRAY);
/*    re_override_debug(stderr,"...back.\n");*/
    SPAGAIN;
    api = POPi;
    if(api == 13) {
      SV* pat;
      long nparens;
      SV* exec_callback_sub;
/*      re_override_debug(stderr,"api 13\n");*/
      if(ret != 4) {
        re_override_debug(stderr,"api 13 violation\n"); exit(0);
      }
      pat = POPs;
      nparens = POPl;
      exec_callback_sub = POPs;
      PUTBACK;
      regexp_setup(aTHX_ r,pat,nparens,exec_callback_sub);
    } else if(api == 14) {
      SV* expr_code;
      SV* expr_result;
/*      re_override_debug(stderr,"api 14\n");*/
      if(ret != 3) {
        re_override_debug(stderr,"api 14 violation\n"); exit(0);
      }
      handler = SvREFCNT_inc(POPs); /*XXX needed? */
      expr_code = POPs;
      PUTBACK;
      expr_result = eval_pv(SvPV_nolen(expr_code),0);
      SPAGAIN;
      XPUSHs(expr_result);
      PUTBACK;
      goto HANDLER_CALL;
    } else {
      re_override_debug(stderr,"api UNKNOWN violation\n"); exit(0);
    }
    re_override_debug(stderr,"hook_regcompp done.\n");
    return r;
  }
}

void regexp_hook_on() {
  if(previous_comp_hook != NULL) { croak("Cant install twice"); }
  previous_comp_hook = PL_regcompp;
  PL_regcompp = &hook_regcompp;
}
void regexp_hook_off() { /* aka "abandon regexps", aka "please segfault" */
  PL_regcompp = previous_comp_hook;
  previous_comp_hook = NULL;
}

MODULE = re::override		PACKAGE = re::override

PROTOTYPES: DISABLE

void
regexp_exechook_insert ()

void
regexp_hook_on ()

void
regexp_hook_off ()

