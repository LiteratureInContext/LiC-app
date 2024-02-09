xquery version "3.1";

(:~ 
 : Webhook endpoint for Syrica.org data repository, /master/ branch: 
 : XQuery endpoint to respond to Github webhook requests. Query responds only to push requests from the master branch.  
 : The EXPath Crypto library supplies the HMAC-SHA1 algorithm for matching Github secret.  
 :
 : Secret can be stored as environmental variable.
 : Will need to be run with administrative privileges, suggest creating a git user with privileges only to relevant app.
 :
 : @Notes 
 : This module is for the PRODUCTION server and picks up calls from refs/heads/master
 : This version uses eXistdb's native JSON parser elminating the need for the xqjson library
 :
 : @author Winona Salesky
 : @version 2.0 
 : 
 : @see http://expath.org/spec/crypto 
 : @see http://expath.org/spec/http-client
 : 
 :)
 
import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace templates="http://exist-db.org/xquery/html-templating" ;
(:import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";:)
import module namespace crypto="http://expath.org/ns/crypto";
import module namespace http="http://expath.org/ns/http-client";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace syriaca = "http://syriaca.org";

declare option exist:serialize "method=xml media-type=text/xml indent=yes";

(: Access git-api configuration file :) 
declare variable $git-config := if(doc('../../access-config.xml')) then doc('../../access-config.xml') else <response status="fail"><message>Load config.xml file please.</message></response>;

(: Private key for authentication :)
declare variable $private-key := if($git-config//private-key-variable != '') then 
       xquery version "3.1";

(:~ 
 : Webhook endpoint for Srophe Web Application 
 : XQuery endpoint to respond to Github webhook requests.  
 : 
 : Requirements
 :  - githubxq library : http://exist-db.org/lib/githubxq 
 :  - EXPath Crypto library : http://expath.org/spec/crypto
 :  - eXist-db 3.0 or greater 
 :  - Must be run with elevated privileges: sm:chmod(xs:anyURI('/db/apps/srophe/modules/git-sync.xql'), "rwsr-xr-x")
 :
 : @author Winona Salesky
 : @version 2.0 
 :)
 
import module namespace githubxq="http://exist-db.org/lib/githubxq";

let $data := request:get-data()
return 
    githubxq:execute-webhook($data, 
        '/db/apps/LiC',  
        'https://github.com/LiteratureInContext/LiC-app', 
        'development', 
        '', 
        '')