(:
Login module/User manager for manuForma application.
2022, Winona Salesky 
:)

xquery version "3.1";

import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://LiC.org/apps/config" at "config.xqm";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
(: Import eXist modules:)
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace http="http://expath.org/ns/http-client";

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";

declare variable $metadata-fullname-key := xs:anyURI("http://axschema.org/namePerson");
declare variable $metadata-description-key := xs:anyURI("http://exist-db.org/security/description");

(: Create a new user :)
declare function local:create-user($data as item()*) as xs:string? {
    let $user := $data?user
    let $fullName := $data?fullName
    let $password := $data?password
    return
        if(matches($user,'^[a-zA-Z0-9]+$')) then 
            if(matches($fullName,'^[a-zA-Z0-9]+$') ) then 
                if(matches($password,'(!\S*\s)')) then 
                    (
                    sm:create-account($user, $password, 'lic', 'admin'),
                    sm:set-umask($user, 18),
                    sm:set-account-metadata($user, $metadata-fullname-key, $fullName),
                    $user
                    )
                else 'Error: Bad Password, try again. (No spaces in Passwords)'
            else 'Error: Unacceptable Characters in Full Name, alphanumeric characters only'
        else 'Error: Unacceptable Characters in Username,  alphanumeric characters only'
};

(: Reset existing password :)
declare function local:resetPW($data as item()*) as xs:string? {
    let $user := $data?user
    let $fullName := $data?fullName
    let $password := $data?password
    return
        sm:passwd($user, $password)
};

(: Delete user :)
declare function local:delete-user($data as item()*) as xs:string? {
    let $user := $data?user
    return sm:remove-account($user) 
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
let $reset := $json-data?reset
return 
   if(sm:list-users() = $userName) then 
        if($reset = 'true') then
            try {
                let $newUser := local:resetPW($json-data)
                return 
                    (
                    response:set-status-code( 200 ),
                    util:declare-option("exist:serialize", "method=json media-type=application/json"),
                    <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                        <message><div>Password for {$userName} has been reset.</div></message>
                    </response>,
                    login:set-user("org.exist.login", (), true())
                    )
                } catch * {
                    (response:set-status-code( 500 ),
                    util:declare-option("exist:serialize", "method=json media-type=application/json"),
                    <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="Failed to update user {$err:code}: {$err:description}">
                        <message>Failed to update user: <error>Caught error {$err:code}: {$err:description}</error></message>
                    </response>)
                }
        else 
            (response:set-status-code( 200 ), 
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="Username already exists">
                <message><div>Username already exists, please select a different username {$userName}.</div></message>
            </response>)
   else if($user != '') then 
        let $newUser := local:create-user($json-data)
        return 
        if(starts-with($newUser),'Error: ') then 
            (response:set-status-code( 500 ),
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="No user data available">
                <message>{$newUser}</message>
            </response>)
        else 
            (
            response:set-status-code( 200 ),
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                <message><div>New user {$userName} has been created. userParam: {request:get-parameter('user', '')}</div></message>
            </response>,
            login:set-user("org.exist.login", (), true())
            )