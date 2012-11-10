/*
 * The routines in this file
 * handle the reading and writing of
 * disk files. All of details about the
 * reading and writing of the disk are
 * in "fileio.c".
 */
#include        <stdio.h>
#include        "ueed.h"

/*
 * Read a file into the current
 * buffer. This is really easy; all you do it
 * find the name of the file, and call the standard
 * "read a file into the current buffer" code.
 * Bound to "C-X C-R".
 */
fileread(f, n)
{
        register int    s;
        char            fname[NFILEN];

        if ((s=mlreply("Read file: ", fname, NFILEN)) != TRUE)
                return (s);
        return (readin(fname));
}

#ifndef OS9
/*
 * Select a file for editing.
 * Look around to see if you can find the
 * fine in another buffer; if you can find it
 * just switch to the buffer. If you cannot find
 * the file, create a new buffer, read in the
 * text, and switch to the new buffer.
 * Bound to C-X C-V.
 */
filevisit(f, n)
{
        register BUFFER *bp;
        register WINDOW *wp;
        register LINE   *lp;
        register int    i;
        register int    s;
        char            bname[NBUFN];
        char            fname[NFILEN];

        if ((s=mlreply("Visit file: ", fname, NFILEN)) != TRUE)
                return (s);
        for (bp=bheadp; bp!=NULL; bp=bp->b_bufp) {
                if ((bp->b_flag&BFTEMP)==0 && strcmp(bp->b_fname, fname)==0) {
                        if (--curbp->b_nwnd == 0) {
                                curbp->b_dotp  = curwp->w_dotp;
                                curbp->b_doto  = curwp->w_doto;
                                curbp->b_markp = curwp->w_markp;
                                curbp->b_marko = curwp->w_marko;
                        }
                        curbp = bp;
                        curwp->w_bufp  = bp;
                        if (bp->b_nwnd++ == 0) {
                                curwp->w_dotp  = bp->b_dotp;
                                curwp->w_doto  = bp->b_doto;
                                curwp->w_markp = bp->b_markp;
                                curwp->w_marko = bp->b_marko;
                        } else {
                                wp = wheadp;
                                while (wp != NULL) {
                                        if (wp!=curwp && wp->w_bufp==bp) {
                                                curwp->w_dotp  = wp->w_dotp;
                                                curwp->w_doto  = wp->w_doto;
                                                curwp->w_markp = wp->w_markp;
                                                curwp->w_marko = wp->w_marko;
                                                break;
                                        }
                                        wp = wp->w_wndp;
                                }
                        }
                        lp = curwp->w_dotp;
                        i = curwp->w_ntrows/2;
                        while (i-- && lback(lp)!=curbp->b_linep)
                                lp = lback(lp);
                        curwp->w_linep = lp;
                        curwp->w_flag |= WFMODE|WFHARD;
                        mlwrite("[Old buffer]");
                        return (TRUE);
                }
        }
        makename(bname, fname);                 /* New buffer name.     */
        while ((bp=bfind(bname, FALSE, 0)) != NULL) {
                s = mlreply("Buffer name: ", bname, NBUFN);
                if (s == ABORT)                 /* ^G to just quit      */
                        return (s);
                if (s == FALSE) {               /* CR to clobber it     */
                        makename(bname, fname);
                        break;
                }
        }
        if (bp==NULL && (bp=bfind(bname, TRUE, 0))==NULL) {
                mlwrite("Cannot create buffer");
                return (FALSE);
        }
        if (--curbp->b_nwnd == 0) {             /* Undisplay.           */
                curbp->b_dotp = curwp->w_dotp;
                curbp->b_doto = curwp->w_doto;
                curbp->b_markp = curwp->w_markp;
                curbp->b_marko = curwp->w_marko;
        }
        curbp = bp;                             /* Switch to it.        */
        curwp->w_bufp = bp;
        curbp->b_nwnd++;
        return (readin(fname));                 /* Read it in.          */
}
#endif

/*
 * Read file "fname" into the current
 * buffer, blowing away any text found there. Called
 * by both the read and visit commands. Return the final
 * status of the read. Also called by the mainline,
 * to read in a file specified on the command line as
 * an argument.
 */
readin(fname)
char    fname[];
{
        register LINE   *lp1;
        register LINE   *lp2;
        register int    i;
        register WINDOW *wp;
        register BUFFER *bp;
        register int    s;
        register int    nbytes;
        register int    nline;
        char            line[NLINE];

        bp = curbp;                             /* Cheap.               */
        if ((s=bclear(bp)) != TRUE)             /* Might be old.        */
                return (s);
        bp->b_flag &= ~(BFTEMP|BFCHG);
        strcpy(bp->b_fname, fname);
        if ((s=ffropen(fname)) == FIOERR)       /* Hard file open.      */
                goto out;
        if (s == FIOFNF) {                      /* File not found.      */
                mlwrite("[New file]");
                goto out;
        }
        mlwrite("[Reading file]");
        nline = 0;
        while ((s=ffgetline(line, NLINE)) == FIOSUC) {
                nbytes = strlen(line);
                if ((lp1=lalloc(nbytes)) == NULL) {
                        s = FIOERR;             /* Keep message on the  */
                        break;                  /* display.             */
                }
                lp2 = lback(curbp->b_linep);
                lp2->l_fp = lp1;
                lp1->l_fp = curbp->b_linep;
                lp1->l_bp = lp2;
                curbp->b_linep->l_bp = lp1;
                for (i=0; i<nbytes; ++i)
                        lputc(lp1, i, line[i]);
                ++nline;
        }
        ffclose();                              /* Ignore errors.       */
        if (s == FIOEOF) {                      /* Don't zap message!   */
                if (nline == 1)
                        mlwrite("[Read 1 line]");
                else
                        mlwrite("[Read %d lines]", nline);
        }
out:
        for (wp=wheadp; wp!=NULL; wp=wp->w_wndp) {
                if (wp->w_bufp == curbp) {
                        wp->w_linep = lforw(curbp->b_linep);
                        wp->w_dotp  = lforw(curbp->b_linep);
                        wp->w_doto  = 
                        wp->w_markp = 
                        wp->w_marko = 0;
                        wp->w_flag |= WFMODE|WFHARD;
                }
        }
        if (s == FIOERR)                        /* False if error.      */
                return (FALSE);
        return (TRUE);
}

/*
 * Take a file name, and from it
 * fabricate a buffer name. This routine knows
 * about the syntax of file names on the target system.
 * I suppose that this information could be put in
 * a better place than a line of code.
 */
makename(bname, fname)
char    bname[];
char    fname[];
{
        register char   *cp1;
        register char   *cp2;

        cp1 = &fname[0];
        while (*cp1 != 0)
                ++cp1;

#ifdef AMIGA
        while (cp1!=&fname[0] && cp1[-1]!=':' && cp1[-1]!='/')
                --cp1;
#endif
#ifdef VMS
        while (cp1!=&fname[0] && cp1[-1]!=':' && cp1[-1]!=']')
                --cp1;
#endif
#ifdef CPM
        while (cp1!=&fname[0] && cp1[-1]!=':')
                --cp1;
#endif
#ifdef MSDOS
        while (cp1!=&fname[0] && cp1[-1]!=':' && cp1[-1]!='\\')
                --cp1;
#endif
#ifdef V7
        while (cp1!=&fname[0] && cp1[-1]!='/')
                --cp1;
#endif
#ifdef OSK
        while (cp1!=&fname[0] && cp1[-1]!='/')
                --cp1;
#endif
        cp2 = &bname[0];
        while (cp2!=&bname[NBUFN-1] && *cp1!=0 && *cp1!=';')
                *cp2++ = *cp1++;
        *cp2 = 0;
}

/*
 * Ask for a file name, and write the
 * contents of the current buffer to that file.
 * Update the remembered file name and clear the
 * buffer changed flag. This handling of file names
 * is different from the earlier versions, and
 * is more compatable with Gosling EMACS than
 * with ITS EMACS. Bound to "C-X C-W".
 */
filewrite(f, n)
{
        register WINDOW *wp;
        register int    s;
        char            fname[NFILEN];

        if ((s=mlreply("Write file: ", fname, NFILEN)) != TRUE)
                return (s);
        if ((s=writeout(fname)) == TRUE) {
                strcpy(curbp->b_fname, fname);
                curbp->b_flag &= ~BFCHG;
                wp = wheadp;                    /* Update mode lines.   */
                while (wp != NULL) {
                        if (wp->w_bufp == curbp)
                                wp->w_flag |= WFMODE;
                        wp = wp->w_wndp;
                }
        }
        return (s);
}

