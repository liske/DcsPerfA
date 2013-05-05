var DPAGraph = new function DPAGraph(id, params) {
    this.id = id;
    this.params = params;

    this.update = function(params) {
	this.params = params;
    }

    this.html = function() {
	return '<img id="' + id + '" />';
    }
}

var DPAGraphs = new function DPAGraphs() {
    var graphs = { };
    var last_id = 0;

    DPAGraphs.getGraph = function(id) {
	return graphs[id];
    }

    DPAGraphs.addGraph = function(params) {
	var id = 'DPAGraph' + last_id++;
	graphs[id] = new DPAGraph(id, params);

	return id;
    }

    DPAGraphs.updateGraph = function(id, params) {
	if(id in graphs) {
	    graphs[id].update(params);
	}
    }

    return DPAGraphs;
}
