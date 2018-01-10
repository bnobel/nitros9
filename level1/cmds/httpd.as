********************************************************************
* httpd - HTTP daemon
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      2013/05/22  Boisy G. Pitre
* Started.
*
*   2      2017/12/21  Boisy G. Pitre
* Added ability to serve image file types, optimized.

               nam       httpd
               ttl       HTTP daemon

               section   __os9
type           equ       Prgrm
lang           equ       Objct
attr           equ       ReEnt
rev            equ       $00
edition        equ       2
stack          equ       200
               endsect

               section   bss
lbufferl       equ       256
lbuffer        rmb       lbufferl+1
dentbuf        rmb       32
filepath       rmb       1
fileptr        rmb       2
filesize       rmb       4
getbufferl     equ       lbufferl
getbuffer      rmb       getbufferl+1
               endsect

               section   code

DEBUG          equ       1

**** Entry Point ****
__start
* Turn off pause in standard out
               lda       #1
               lbsr      SetEchoOff
               lbsr      SetAutoLFOn

* change to www root dir
               lda       #READ.
               leax      wwwroot,pcr
               os9       I$ChgDir
               bcs       errexit
                              
* nul out getbuffer
               clr       getbuffer,u

* main loop: read line on stdin
mainloop
               leax      lbuffer,u
               ldy       #lbufferl
               clra
               os9       I$ReadLn
               bcs       checkeof
* quickly nul terminate the line we just read
               pshs      x
               tfr       y,d
               leax      d,x
               clr       -1,x
               puls      x
               bsr       process
               bra       mainloop
               
checkeof       cmpb      #E$EOF
               bcs       errexit
okexit         clrb
errexit        
               pshs      cc,b
               lda       #1
               lbsr      SetEchoOn
               puls      cc,b
               os9       F$Exit

* input: X = line read (nul terminated)
process
* check for empty line
               tst       ,x              nul byte?
               bne       checkGET        if not, continue
               bsr       processGET
               bra       okexit
                
* check for GET
checkGET       leay      get,pcr
               ldd       #getl
               lbsr      STRNCMP
               beq       CopyGET
               clrb
               rts

* copy line with GET into our get buffer
CopyGET        leay      getbuffer,u
               lbsr      STRCPY
bye            rts

* we know it is a GET... get the text following it               
processGET
               leax      getbuffer,u
               tst       ,x
               beq       bye
               leax      4,x
               ldd       ,x
               cmpd      #'/*256+C$SPAC
               beq       doindex
               leax      1,x
               
NulTerminate   pshs      x
loop@          lda       ,x+
               beq       terminate@
               cmpa      #C$CR
               beq       terminate@
               cmpa      #C$SPAC
               beq       terminate@
               bra       loop@
terminate@     clr       -1,x
               puls      x
               bra       readfile

* point to default page
doindex        leax      index,pcr               
readfile
               stx       fileptr,u
               lda       #READ.
               os9       I$Open
               bcs       isitdir

* get file size
*               ldb       #SS.Size              
*               tfr       u,y
*               pshs      x,u
*               os9       I$GetStt
*               bcs       err@
*               stx       filesize,y
*               stu       filesize+2,y
*err@           puls      x,u

* get file type via extension
* X points to last character in path + 1
               pshs      a,x,y
l@             leax      -1,x
               lda       ,x
               cmpx      1,s     reached start?
               beq       end@
               cmpa      #'.
               bne       l@
               leax      1,x
* X points to the extension
end@           lbsr      getContentType
               lbsr      print200OK
               puls      a,x,y

readloop       leax      lbuffer,u
               ldy       #lbufferl
               os9       I$Read
               bcs       eofcheck
               pshs      a
               lda       #1
               os9       I$Write
               puls      a
               bra       readloop

eofcheck       cmpb      #E$EOF
               bne       ret
               clrb
               os9       I$Close
ret            rts

isitdir        cmpb      #E$FNA
               lbne      notfound
* open as directory
               lda       #READ.+DIR.
               ldx       fileptr,u
               os9       I$Open
               lbcs      notfound
* process dir here
               sta       filepath,u
               leax      htmlcontenttype,pcr
               lbsr      print200OK
               lbsr      _htmltag
               lbsr      _headtag
               lbsr      _titletag
               lbsr      PRINTS
               fcc       "Directory of "
               fcb       $00
               ldx       fileptr,u
               lbsr      PUTS
               lbsr      _ntitletag
               lbsr      _nheadtag
               lbsr      _bodytag
               lbsr      PRINTS
               fcc       "<H3>"
               fcc       "Directory of "
               fcb       $00
               ldx       fileptr,u
               lbsr      PUTS
               lbsr      PRINTS
               fcc       "</H3>"
               fcb       $00
               lda       filepath,u
* skip over .. and .               
               ldy       #DIR.SZ
               leax      dentbuf,u
               os9       I$Read
               leax      dentbuf,u
               os9       I$Read

nextdirent     lda       filepath,u
               leax      dentbuf,u
               ldy       #DIR.SZ
               os9       I$Read
               bcs       endoffile
               tst       ,x
               beq       nextdirent
               
* find char with hi bit set
               tfr       x,y
lo@            lda       ,y+
               bpl       lo@               
               anda      #$7F
               sta       -1,y
               clr       ,y
               pshs      x
               lbsr      PRINTS
               fcc       '<A HREF="'
               fcb       $00
               ldx       fileptr,u
               lbsr      PUTS
               lbsr      PRINTS
               fcc       "/"
               fcb       $00
               ldx       ,s
               lbsr      PUTS
               lbsr      PRINTS
               fcc       '">'
               fcb       $00
               puls      x
               lbsr      PUTS
               lbsr      PRINTS
               fcc       "</A>"
               fcc       "<BR>"
               fcb       $00
               bra       nextdirent
endoffile               
               lda       filepath,u
               os9       I$Close
               lbsr      _nbodytag
               lbsr      _nhtmltag
               rts
               
notfound       lbsr      print404
               rts

_http11
               lbsr      PRINTS
               fcc       "HTTP/1.1 "
               fcb       $00
               rts

_server
               lbsr      PRINTS
               fcc       "Server: "
               fcb       $00
               lbsr      _serverinf
               lbsr      _newline
               rts

*_contentlength
*               lbsr      PRINTS
*               fcc       "Content-Length: "
*               fcb       $00
*               pshs      a
*               ldd       filesize+2,u
*               lbsr      PRINT_DEC
*               puls      a
*               lbsr      PRINTS
*               fcb       C$CR,$00
*               rts

_contenttype
               lbsr      PRINTS
               fcc       "Content-Type: "
               fcb       $00
               rts

_connclose
               lbsr      PRINTS
               fcc       "Connection: close"
               fcb       C$CR,$00
               rts

_newline
               lbsr      PRINTS
               fcb       C$CR,$00
               rts

_serverinf
               lbsr      PRINTS
               fcc       /httpd ed. /
               fcb       edition+$30
               fcc       / (NitrOS-9)/
               fcb       $00
               rts                        

_htmltag
               lbsr      PRINTS
               fcc       "<HTML>"
               fcb       $00
               rts                        

_nhtmltag
               lbsr      PRINTS
               fcc       "</HTML>"
               fcb       $00
               rts                        

_headtag
               lbsr      PRINTS
               fcc       "<HEAD>"
               fcb       $00
               rts                        

_nheadtag
               lbsr      PRINTS
               fcc       "</HEAD>"
               fcb       $00
               rts                        

_titletag
               lbsr      PRINTS
               fcc       "<TITLE>"
               fcb       $00
               rts                        

_ntitletag
               lbsr      PRINTS
               fcc       "</TITLE>"
               fcb       $00
               rts                        

_bodytag
               lbsr      PRINTS
               fcc       "<BODY>"
               fcb       $00
               rts                        

_nbodytag
               lbsr      PRINTS
               fcc       "</BODY>"
               fcb       $00
               rts                        

* X = address of nul-terminated content type string
print200OK
               lbsr      _http11
               lbsr      PRINTS
               fcc       "200 OK"
               fcb       C$CR,$00
               lbsr      _server
               lbsr      _contenttype
               lbsr      PUTS           content type
               lbsr      _newline
               lbsr      _connclose
               lbsr      _newline
               rts
                     

print404
               lbsr      _http11
               lbsr      PRINTS
               fcc       "404 Not Found"
               fcb       C$CR,$00
               lbsr      _server
               lbsr      _connclose
               lbsr      _newline
               lbsr      PRINTS
			   fcc       '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
               fcb       $00
			   lbsr      _htmltag
			   lbsr      _headtag
			   lbsr      PRINTS
               fcc       '<title>404 Not Found</title>'
               fcb       $00
               lbsr      _nheadtag
               lbsr      _bodytag
			   lbsr      PRINTS
               fcc       '<h1>Not Found</h1>'
               fcc       '<p>The requested URL '
               fcb       $00
               ldx       fileptr,u
               lbsr      PUTS               
               lbsr      PRINTS
               fcc       ' was not found on this server.</p>'
               fcc       '<hr>'
               fcc       '<address>'
               fcb       $00
               lbsr      _serverinf
               lbsr      PRINTS
               fcc       '</address>'
               fcb       $00
               lbsr      _nbodytag
               lbsr      _nhtmltag
               rts
                                             
wwwroot        fcs       "....../WWWROOT"
get            fcc       "GET "
getl           equ       *-get               
               fcb       $00
index          fcc       "index.html"
               fcb       $00
* supported file types
htmlcontenttype
               fcc       "text/"
htmlext        fcc       "html"
               fcb       $00

pngcontenttype
               fcc       "image/"
pngext         fcc       "png"
               fcb       $00

jpgcontenttype
               fcc       "image/"
jpgext         fcc       "jpg"
               fcb       $00

jpegcontenttype
               fcc       "image/"
jpegext        fcc       "jpeg"
               fcb       $00

gifcontenttype
               fcc       "image/"
gifext         fcc       "gif"
               fcb       $00

icocontenttype
               fcc       "image/x-icon"
               fcb       $00
icoext         fcc       "ico"
               fcb       $00

textcontenttype
               fcc       "text/"
textext        fcc       "text"
               fcb       $00

exttable       fdb       htmlext-exttable,htmlcontenttype-exttable
               fdb       pngext-exttable,pngcontenttype-exttable
               fdb       jpgext-exttable,jpgcontenttype-exttable
               fdb       jpegext-exttable,jpegcontenttype-exttable
               fdb       icoext-exttable,icocontenttype-exttable
               fdb       gifext-exttable,gifcontenttype-exttable
               fdb       $0000
               
* Entry: X = ptr to extension
* Exit:  X = ptr to nul-terminated content type string
getContentType
               pshs      y,u
               leau      exttable-4,pcr
l@             leau      4,u
               ldd       ,u
               beq       default@
               leay      exttable,pcr
               leay      d,y
               lbsr      STRCMP
               bne       l@
match@         leax      exttable,pc
               ldd       2,u
               leax      d,x
               puls      y,u,pc
default@       leax      textcontenttype,pcr
               puls      y,u,pc

               endsect
