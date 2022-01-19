function background(uri,q,callback,method) {
	var xmlHttpReq = false;
	//alert(uri);
	//alert(q);

	if (window.XMLHttpRequest) {
	    xmlHttpReq = new XMLHttpRequest();
//	    xmlHttpReq.overrideMimeType('text/xml');
	} else if (window.ActiveXObject) {
	    xmlHttpReq = new ActiveXObject("Microsoft.XMLHTTP");
	}

	if (method == null) {
		method = 'POST';
	}
	xmlHttpReq.open(method, uri, true);
	xmlHttpReq.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
	if(callback)
		xmlHttpReq.onreadystatechange = function(){
			if (xmlHttpReq.readyState == 4) {
				if(typeof callback == 'function'){
//                    alert(xmlHttpReq.responseText);
					callback(xmlHttpReq.responseText);
				}else{
					eval(callback);
				}
			}
		}
	xmlHttpReq.send(q);
}


// Background fetches a page into the specified element
function fetch_into(div, uri, q, callback, method) {
	var xmlHttpReq = false;
	//alert(uri);
	//alert(q);
	//alert(uri+'?'+q);
// Mozilla/Safari 
    var target = document.getElementById(div);
    if(!target){
        return;
    }
	if (window.XMLHttpRequest) {
		xmlHttpReq = new XMLHttpRequest();
		if (typeof xmlHttpReq.overrideMimeType != 'undefined') { 
			xmlHttpReq.overrideMimeType('text/xml');
		}
	}
// IE 
	else if (window.ActiveXObject) {
		xmlHttpReq = new ActiveXObject("Microsoft.XMLHTTP");
	}
    //var fd = new FormData();
	if (method == null) {
		method = 'POST';
	}
	xmlHttpReq.open(method, uri, true);
	xmlHttpReq.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
	xmlHttpReq.onreadystatechange = function() {
		if (xmlHttpReq.readyState == 4) {
            target.innerHTML=xmlHttpReq.responseText;
            if(callback){
                if(typeof callback == 'function'){
                    callback.call();
                }else{
                    eval(callback);
                }
            }
		}
	}
//	alert(q);
	xmlHttpReq.send(q);
}
