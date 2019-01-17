xquery version "3.0";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="http://LiC.org/config";

declare namespace templates="http://exist-db.org/xquery/templates";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;
(: Get repo-config.xml to parse global varaibles :)
declare variable $config:get-config := doc($config:app-root || '/repo-config.xml');

(: Get access-config.xml to parse global varaibles :)
declare variable $config:get-access-config := doc($config:app-root || '/access-config.xml');

(: Establish data root defined in repo.xml 'data-root' name of eXist app :)
declare variable $config:data-root := 
    let $app-root := $config:get-config//repo:app-root/text()  
    let $data-root := concat($config:get-config//repo:data-root/text(),'/data') 
    return
       replace($config:app-root, $app-root, $data-root)
    ;

(: Establish main navigation for app, used in templates for absolute links. Syriaca.org uses a development and production server which each have different root directories.  :)
declare variable $config:nav-base := 
    if($config:get-config//repo:nav-base/text() != '') then $config:get-config//repo:nav-base/text()
    else if($config:get-config//repo:nav-base/text() = '/') then ''
    else '';
    
declare variable $config:base-uri := $config:get-config//repo:base_uri/text();

declare variable $config:app-title := $config:get-config//repo:title/text();

declare variable $config:app-url := $config:get-config//repo:url/text();

declare variable $config:image-root := if($config:get-config//repo:page-images-root/text() != '') then
                                           $config:get-config//repo:page-images-root/text()
                                       else (); 
declare variable $config:tei2html := $config:get-config//repo:work-html-transformation;
declare variable $config:tei2pdf := $config:get-config//repo:work-pdf-transformation;
declare variable $config:tei2epub := $config:get-config//repo:work-epub-transformation;

(: Map rendering, google or leaflet :)
declare variable $config:app-map-option := $config:get-config//repo:maps/repo:option[@selected='true']/text();

(: Map key for google maps:)
declare variable $config:map-api-key := $config:get-config//repo:maps/repo:option[@selected='true']/@api-key;

(:~
 : Enable reCAPTCHA
 : @see: https://developers.google.com/recaptcha/intro to get started.
 : @see: SAMLE access-config file.  
:)
declare variable $config:recaptcha := 
    if($config:get-access-config) then
        if($config:get-access-config//recaptcha/site-key-variable != '') then 
            environment-variable($config:get-access-config//recaptcha/site-key-variable/text())
        else $config:get-access-config//private-key/text()
    else ();

(:~
 : @NOTE, may not use. 
 : Sub in relative paths based on base-url variable
 : @para @uri as xs:string 
 :)
declare function config:internal-links($uri as xs:string?){
    replace($uri,$config:base-uri,$config:nav-base)
};

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};

declare function config:app-meta($node as node(), $model as map(*)) as element()* {
    <meta xmlns="http://www.w3.org/1999/xhtml" name="description" content="{$config:repo-descriptor/repo:description/text()}"/>,
    for $author in $config:repo-descriptor/repo:author
    return
        <meta xmlns="http://www.w3.org/1999/xhtml" name="creator" content="{$author/text()}"/>
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $model as map(*)) {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
        <table class="app-info">
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            {
                for $attr in ($expath/@*, $expath/*, $repo/*)
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }
            <tr>
                <td>Controller:</td>
                <td>{ request:get-attribute("$exist:controller") }</td>
            </tr>
        </table>
};