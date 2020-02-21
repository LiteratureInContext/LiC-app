xquery version "3.1";

import module namespace config="http://LiC.org/config" at "../modules/config.xqm";
import module namespace d3xquery="http://syriaca.org/d3xquery" at "d3xquery.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace json="http://www.json.org";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";


<html xmlns="http://www.w3.org/1999/xhtml">
    <meta charset="UTF-8"/>
    <title>d3xquery</title>
    <link rel="stylesheet" type="text/css" href="$nav-base/resources/bootstrap/css/bootstrap.min.css"/>
    <link rel="stylesheet" href="relationships.css"/>
    <link rel="stylesheet" href="pygment_trac.css"/>
    <script type="text/javascript" src="$nav-base/resources/js/jquery.min.js"/>
    <script src="https://d3js.org/d3.v4.min.js"></script>
    <!--<script src="//d3js.org/d3.v3.min.js"></script>-->
    <script><![CDATA[
        $(document).ready(function () {
            //Start bubble chart here
            //Get JSON data
            var type = ']]>{request:get-parameter('type', '')}<![CDATA[';
            selectGraphType(type)
            //console.log(data[0].children)
            });
    ]]></script>
    <style><![CDATA[
        .d3jstooltip {
          background-color:white;
          border: 1px solid #ccc;
          border-radius: 6px;
          padding:.5em;
          }
        }]]>
        </style>
    <body>
        <h1>Data Visualizations</h1>
        <div id="tooltip"/>
        <div id="result"/>

    </body>
    <!--<script src="bubble.js"/>-->
    <script src="visualizations.js"/>
</html>
