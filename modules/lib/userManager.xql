(:
Login module/User manager for LiC application.
2019, Winona Salesky
:)

xquery version "3.1";

import module namespace config="http://LiC.org/config" at "../config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace http="http://expath.org/ns/http-client";

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";

declare variable $metadata-fullname-key := xs:anyURI("http://axschema.org/namePerson");
declare variable $metadata-description-key := xs:anyURI("http://exist-db.org/security/description");

(: Create a new user preset group to lic :)
declare function local:create-user($data as item()*) as xs:string? {
    let $user := $data?user
    let $fullName := $data?fullName
    let $password := $data?password
    return
        (sm:create-account($user, $password, 'lic'),
        sm:set-umask($user, 18),
        sm:set-account-metadata($user, $metadata-fullname-key, $fullName),
        $user
        )
};

(: Delete user :)
declare function local:delete-user($data as item()*) as xs:string? {
    let $user := $data?user
    return sm:remove-account($user)
};

(:
 : Login new user
 : Borrowed from persistent login module: resource:org/exist/xquery/modules/persistentlogin/login.xql
 :)
declare function local:set-user($user as xs:string?, $password as xs:string?, $maxAge as xs:dayTimeDuration?) {
    let $duration :=
        if (exists($maxAge)) then
            $maxAge
        else ()
    let $cookie := request:get-cookie-value($config:login-domain)
    return
       (login:set-user($config:login-domain, (), true()),
        request:set-attribute($config:login-domain || ".user", $user),
        request:set-attribute("xquery.user", $user),
        request:set-attribute("xquery.password", $password)
       )
};

(: Create new user :)
let $post-data := 
              if(not(empty(request:get-data()))) then request:get-data()
              else 'no data'
let $payload := util:base64-decode($post-data)
let $json-data := parse-json($payload)
let $userName := $json-data?user
let $user := $json-data?user
let $password := $json-data?password              
return 
   if(sm:list-users() = $userName) then 
        (response:set-status-code( 200 ), 
        util:declare-option("exist:serialize", "method=json media-type=application/json"),
        <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="username already exists">
            <message><div>Username already exists, please select a different username {$userName}.</div></message>
        </response>)
    else if($user != '') then 
      try {
        let $newUser := local:create-user($json-data)
        (: Login new user:)
        let $login := local:set-user($user, $password, ())
        return 
            (
            response:set-status-code( 200 ),
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                <message><div>New user {$userName} has been created. userParam: {request:get-parameter('user', '')}</div></message>
            </response>)
        } catch * {
            (response:set-status-code( 500 ),
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="failed to create user">
                <message>Failed to create user: <error>Caught error {$err:code}: {$err:description}</error></message>
            </response>)
        }
    else  
        (response:set-status-code( 500 ),
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="No user data available">
                <message>No user data available</message>
            </response>)