//Saved while test tooltip issue
/* Global vars */
var width = 1020,
    height = 500
    color = d3.scaleOrdinal(d3.schemeCategory20);
    
/* Set up svg */
var svg = d3.select("#result")
    .append("svg")
    .attr("width", width)
    .attr("height", height)
    .style("border", "1px solid grey");

var tooltip = d3.selectAll("#tooltip")
	.attr("class", "d3jstooltip")
	.style("position","fixed")
	.style("opacity", 0);
	
/* Select graph type */
function selectGraphType(type) {
    if (type === "Table") {
        console.log(type + ' cant do that one yet');
        //  htmltable()
    } else if (type === 'Force') {
        //console.log(type + ' cant do that one yet');
        forcegraph()
    } else if (type === 'Sankey') {
        console.log(type + ' cant do that one yet');
        //  sankey()
    } else if (type === 'Bubble') {
        //console.log(type + ' cant do that one yet');
        bubble()
    } else if (type === 'Raw XML') {
        console.log(type + ' cant do that one yet');
        //  rawXML()
    } else if (type === 'Raw JSON') {
        console.log(type + ' cant do that one yet');
        //  rawJSON()
    } else {
        console.log(type + ' cant do that one yet');
    }
};

/* Force Graph */
function forcegraph() {
    //var color = d3.scaleOrdinal(d3.schemeCategory20);
    var radius = 6;

    var simulation = d3.forceSimulation()
        .force("link", d3.forceLink().id(function(d) { return d.id; }))
        .force("charge", d3.forceManyBody().strength(-15))
        .force("center", d3.forceCenter(width / 2, height / 2));
    
    d3.json("d3xquery.xql?type=Force", function(error, graph) {
        if (error) throw error;

        console.log(graph);
            
        var link = svg.append("g")
            .attr("class", "links")
            .selectAll("line")
            .data(graph.links)
            .enter().append("line")
            .style("stroke","#999");
        
          var node = svg.append("g")
              .attr("class", "nodes")
            .selectAll("g")
            .data(graph.nodes)
            .enter().append("g");
            
          var circles = node.append("circle")
            .attr("r", 6)
            .attr("fill", function(d) { return color(d.type); })
            .attr("stroke", function(d) { return d3.rgb(color(d.type)).darker(); })
            .call(d3.drag()
                  .on("start", dragstarted)
                  .on("drag", dragged)
                  .on("end", dragended))
            .on("mouseover", function (d) {
                    d3.select(this).attr("r", 14);
                    d3.select(this).style("opacity", 1);
                    return tooltip.style("visibility", "visible").text(d.label).style("opacity", 1).style("left", (d3.event.pageX) + "px").style("top", (d3.event.pageY + 10) + "px");
                }).on("mouseout", function (d) {
                    d3.select(this).attr("r", 6);
                    d3.select(this).style("opacity", .5);
                    return tooltip.style("visibility", "hidden");
                }).on("mousemove", function () {
                    return tooltip.style("top", (event.pageY -10) + "px").style("left",(event.pageX + 10) + "px");
                }).on('dblclick', function(d,i){
                     var view = (d.type === 'place') ? 'map':'persName';
                     var url = (d.type === 'work') ? '../work/' + d.uri : "../lod.html?view=" + view +"&id=" + d.id;
                     window.location = url;
                 });  
                
          node.append("title")
              .text(function(d) { return d.id; });
        
          simulation
              .nodes(graph.nodes)
              .on("tick", ticked);
        
          simulation.force("link")
              .links(graph.links);
        
          function ticked() {
            link
                .attr("x1", function(d) { return d.source.x; })
                .attr("y1", function(d) { return d.source.y; })
                .attr("x2", function(d) { return d.target.x; })
                .attr("y2", function(d) { return d.target.y; });
          
            circles
                .attr("cx", function(d) { return d.x = Math.max(radius, Math.min(width - radius, d.x)); })
                .attr("cy", function(d) { return d.y = Math.max(radius, Math.min(height - radius, d.y)); });
          }
  });
  
  function dragstarted(d) {
    if (!d3.event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  }
  
  function dragged(d) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
  }
  
  function dragended(d) {
    if (!d3.event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  }
  
};

function bubble() {
    
    d3.json("d3xquery.xql?type=Bubble", function(error, graph) {
     console.log('data')
     
     //Data
     data = graph.data.children;
     
     var n = data.length, // total number of circles
         m = 10, // number of distinct clusters
         maxRadius = 12;
     
     //color based on cluster
     var c = d3.scaleOrdinal(d3.schemeCategory10).domain(d3.range(m));
     
     // The largest node for each cluster.
     var clusters = new Array(m);
    
     var nodes = data.map(function(d) {
        var i = d.type,
            l = d.name,
            s = d.size,
            id = d.id,
            r =  (d.size < 3) ? Math.floor(d.size * 6):Math.floor(d.size * 2);
            //Math.floor(d.size * 3); 
            //Math.sqrt((d.size + 1) / m * -Math.log(Math.random())) * maxRadius,
            d = {cluster: i, radius: r, name: l, size: s, id: id};
        if (!clusters[i] || (r > clusters[i].radius)) clusters[i] = d;
        return d;
      });
    console.log(data);
    console.log(nodes);
    
    var forceCollide = d3.forceCollide()
        .radius(function(d) { return d.radius + 1.5; })
        .iterations(1);
    
    var force = d3.forceSimulation()
        .nodes(nodes)
        .force("center", d3.forceCenter())
        .force("collide", forceCollide)
        .force("cluster", forceCluster)
        .force("gravity", d3.forceManyBody(30))
        .force("x", d3.forceX().strength(.7))
        .force("y", d3.forceY().strength(.7))
        .on("tick", tick);
        
    var g = svg
        .append('g')
        .attr('transform', 'translate(' + width / 2 + ',' + height / 2 + ')');
        
    var circle = g.selectAll("circle")
        .data(nodes)
      .enter().append("circle")
        .attr("r", function(d) { return d.radius; })
        .style("fill", function(d) { return color(d.cluster); })
        .attr("stroke", function(d) { return d3.rgb(color(d.cluster)).darker(); })
        .on("mouseover", function (d) {
            d3.select(this).style("opacity", .5);
            return tooltip.style("visibility", "visible").text(d.name + ' mentioned in ' + d.size + ' work(s)').style("opacity", 1).style("left", (d3.event.pageX) + "px").style("top", (d3.event.pageY + 10) + "px");
        }).on("mouseout", function (d) {
            d3.select(this).style("opacity", 1);
            return tooltip.style("visibility", "hidden");
        }).on("mousemove", function () {
            return tooltip.style("top", (event.pageY -10) + "px").style("left",(event.pageX + 10) + "px");
        }).on('dblclick', function(d,i){
            var view = (d.cluster === 'place') ? 'map':'persName';
            var url = "../lod.html?view=" + view +"&id=" + d.id;
            window.location = url;
        });  
    
    function tick() {
      circle
          .attr("cx", function(d) { return d.x; })
          .attr("cy", function(d) { return d.y; });
    }
    
    function forceCluster(alpha) {
      for (var i = 0, n = nodes.length, node, cluster, k = alpha * 1; i < n; ++i) {
        node = nodes[i];
        cluster = clusters[node.cluster];
        node.vx -= (node.x - cluster.x) * k;
        node.vy -= (node.y - cluster.y) * k;
      }
    }        
    //end json
    });
   
};