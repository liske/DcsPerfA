function DPAGraph(pid, id, params) {
    this.id = id;

    this.setParams = function(params) {
	this.params = params;
	this.setSrc();
    }

    this.getParams = function() {
	return params;
    }

    this.setSrc = function() {
	$('#' + id).attr('src', 'plot/?params=' +
	    encodeURIComponent(JSON.stringify(params)).replace(/[!'()]/g, escape).replace(/\*/g, "%2A") //'
	);
    }

    var close = $('<div/>', {
	title: 'close',
	class: 'close',
	html: '<b>x</b>',
    });
    close.click(function() {
	$('#div_' + id).remove();
    });

    $('<div/>', {
	id: 'div_' + id,
	class: 'drag',
    }).appendTo(pid).draggable().append('<img id="' + id + '" />').append(close);
    this.setParams(params);
}

var DPAGraphs = new function DPAGraphs() {
    var graphs = { };
    var last_id = 0;

    DPAGraphs.getGraph = function(id) {
	return graphs[id];
    }

    DPAGraphs.addGraph = function(pid, params) {
	var id = 'DPAGraph' + last_id++;
	graphs[id] = new DPAGraph(pid, id, params);

	return graphs[id];
    }

    DPAGraphs.updateGraph = function(id, params) {
	if(id in graphs) {
	    graphs[id].update(params);
	}
    }

    return DPAGraphs;
}
