xquery version "3.0";

module namespace maps = "http://LiC.org/apps/maps";

(:~
 : Module builds leafletjs maps and/or Google maps
 : Pulls geoJSON from http://syriaca.org/geojson module. 
 : 
 : @author Winona Salesky <wsalesky@gmail.com> 
 : @authored 2014-06-25
:)
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace geojson = "http://syriaca.org/srophe/geojson" at "../content-negotiation/geojson.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~
 : Selects map rendering based on config.xml entry
:)
declare function maps:build-map($nodes as node()*){
    <div id="map-data" style="margin-bottom:3em;">
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.awesome-markers.min.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.markercluster-src.js"/>
        <div id="map"/>
        <script type="text/javascript">
            <![CDATA[
                  var geoJsonData = ]]>{geojson:geojson($nodes,'')}<![CDATA[;
                  
                  var terrain = L.tileLayer('http://api.tiles.mapbox.com/v3/sgillies.map-ac5eaoks/{z}/{x}/{y}.png', {attribution: "ISAW, 2012"});
          		var tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          			maxZoom: 18,
          			attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          		});
          
          		var map = L.map('map').addLayer(tiles);
          
          		var markers = L.markerClusterGroup();
          
          		var geoJsonLayer = L.geoJson(geoJsonData, {
          			onEachFeature: function (feature, layer) {
          				  var typeText = feature.properties.type
                            var popupContent = 
                                "<a href='" + feature.properties.relation.id + "' class='map-pop-title'>" +
                                feature.properties.relation.title + "</a>" + 
                                "<br/>Location: <a href='" + feature.properties.uri + "' class='map-pop-title'>" +
                                feature.properties.name + "</a>"  +
                                "<br/>Relationship: " + typeText + 
                                (feature.properties.desc ? "<span class='map-pop-desc'>"+ feature.properties.desc +"</span>" : "");
          				layer.bindPopup(popupContent);
          			}
          		});
          		markers.addLayer(geoJsonLayer);
                  
          		map.addLayer(markers);
          		map.fitBounds(markers.getBounds());
            ]]>
        </script>
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>
    </div> 
};

declare function maps:build-map-subset($nodes as node()*){
    <div id="map-data" style="margin-bottom:3em;">
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.awesome-markers.min.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.markercluster-src.js"/>
        <div id="map"/>
        <script type="text/javascript">
            <![CDATA[
                   
                  var geoJsonData = ]]>{geojson:geojson($nodes,'subset')}<![CDATA[;
                  
                  var terrain = L.tileLayer('http://api.tiles.mapbox.com/v3/sgillies.map-ac5eaoks/{z}/{x}/{y}.png', {attribution: "ISAW, 2012"});
          		var tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          			maxZoom: 18,
          			attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          		});
                   
          		var map = L.map('map').addLayer(tiles); 
          		var markers = L.markerClusterGroup();
          		var geoJsonLayer = L.geoJson(geoJsonData, {
          			onEachFeature: function (feature, layer) {
          				  var typeText = feature.properties.type
                            var popupContent = 
                                "<a href='" + feature.properties.relation.id + "' class='map-pop-title'>" +
                                feature.properties.relation.title + "</a>" + 
                                "<br/>Location: <a href='" + feature.properties.uri + "' class='map-pop-title'>" +
                                feature.properties.name + "</a>"  +
                                "<br/>Relationship: " + typeText + 
                                (feature.properties.desc ? "<span class='map-pop-desc'>"+ feature.properties.desc +"</span>" : "");
          				layer.bindPopup(popupContent);
          			}
          		});
          		
          		markers.addLayer(geoJsonLayer);
          		map.addLayer(markers);
          		map.fitBounds(markers.getBounds());
          		$('#teiViewLOD').on('shown.bs.collapse', function () {
                       map.invalidateSize();
                       map.fitBounds(markers.getBounds());
                   });
          	    

            ]]>
        </script>
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>
    </div> 
};

declare function maps:build-map-work($nodes as node()*, $id){
    <div id="map-data" style="margin-bottom:3em;">
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.awesome-markers.min.js"/>
        <script type="text/javascript" src="{$config:nav-base}/resources/leaflet/leaflet.markercluster-src.js"/>
        <div id="map"/>
        <script type="text/javascript">
            <![CDATA[
                   
                  var geoJsonData = ]]>{geojson:geojson($nodes,'subset', $id)}<![CDATA[;
                  
                  var terrain = L.tileLayer('http://api.tiles.mapbox.com/v3/sgillies.map-ac5eaoks/{z}/{x}/{y}.png', {attribution: "ISAW, 2012"});
          		var tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          			maxZoom: 18,
          			attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          		});
                   
          		var map = L.map('map').addLayer(tiles); 
          		var markers = L.markerClusterGroup();
          		var geoJsonLayer = L.geoJson(geoJsonData, {
          			onEachFeature: function (feature, layer) {
          				  var typeText = feature.properties.type
                            var popupContent = 
                                "<a href='" + feature.properties.relation.id + "' class='map-pop-title'>" +
                                feature.properties.relation.title + "</a>" + 
                                "<br/>Location: <a href='" + feature.properties.uri + "' class='map-pop-title'>" +
                                feature.properties.name + "</a>"  +
                                "<br/>Relationship: " + typeText + 
                                (feature.properties.desc ? "<span class='map-pop-desc'>"+ feature.properties.desc +"</span>" : "");
          				layer.bindPopup(popupContent);
          			}
          		});
          		
          		markers.addLayer(geoJsonLayer);
          		map.addLayer(markers);
          		map.fitBounds(markers.getBounds());
          		$('#teiViewLOD').on('shown.bs.collapse', function () {
                       map.invalidateSize();
                       map.fitBounds(markers.getBounds());
                   });
          	    

            ]]>
        </script>
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>
    </div> 
};