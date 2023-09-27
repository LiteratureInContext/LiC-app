xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";

import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(
(: Set UID for git-sync. :)
sm:chmod(xs:anyURI($target || '/modules/lib/git-sync.xql'), "rwsr-xr-x"),
sm:chmod(xs:anyURI($target || '/modules/lib/userManager.xql'), "rwsr-xr-x"),
sm:chmod(xs:anyURI($target || '/modules/lib/coursepack.xql'), "rwxrwxr-x"),
sm:chmod(xs:anyURI($target || '/modules/build-lod.xql'), "rwsr-xr-x"),
sm:chmod(xs:anyURI($target || '/coursepacks'), "rwxrwxr-x"),
sm:chgrp(xs:anyURI($target || '/coursepacks'), "lic"),
(: create lic group for coursepack users :)
sm:create-group('lic')
)