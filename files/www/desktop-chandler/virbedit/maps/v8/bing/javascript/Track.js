// Leaflet replacement for VIRB Edit Google Track.js
// Compatible with IE11 (ES5 only) + TrackIntf.js bridge (window.external)
function SetTrackImpl(aLatList, aLngList)
{
    var theLats, theLngs;
    try { theLats = $.parseJSON(aLatList); } catch (e) { theLats = []; }
    try { theLngs = $.parseJSON(aLngList); } catch (e) { theLngs = []; }
    if (!mTrack)
    {
        mTrack = new Track(mMap, theLats, theLngs);
    }
    else
    {
        mTrack.UpdateTrack(theLats, theLngs);
    }
}

function AddTrackImpl(aLatList, aLngList)
{
    var theLats, theLngs;
    try { theLats = $.parseJSON(aLatList); } catch (e) { return; }
    try { theLngs = $.parseJSON(aLngList); } catch (e) { return; }
    if (!mTrack) { return; }
    return mTrack.AddTrack(theLats, theLngs);
}

function SetTrackSegmentImpl(aLatList, aLngList)
{
    if (!mTrack) { return; }
    var theLats, theLngs;
    try { theLats = $.parseJSON(aLatList); } catch (e) { return; }
    try { theLngs = $.parseJSON(aLngList); } catch (e) { return; }
    mTrack.SetSegment(theLats, theLngs);
}

function AddBackgroundTrackImpl(aLatList, aLngList)
{
    if (!mTrack) { return; }
    var theLats, theLngs;
    try { theLats = $.parseJSON(aLatList); } catch (e) { return; }
    try { theLngs = $.parseJSON(aLngList); } catch (e) { return; }
    mTrack.AddBackgroundTrack(theLats, theLngs);
}

function SetMarkerPositionImpl(aLat, aLon)
{
    if (!mTrack) { return; }
    mTrack.SetMarkerPosition(aLat, aLon);
}

var Track = (function ()
{
    function toLatLngs(aLats, aLngs)
    {
        var list = [];
        var n = Math.min(aLats.length, aLngs.length);
        var i;
        for (i = 0; i < n; i++)
        {
            list.push(L.latLng(aLats[i], aLngs[i]));
        }
        return list;
    }

    function makeBounds(list)
    {
        if (!list || list.length === 0) { return null; }
        return L.latLngBounds(list);
    }

    function Track(aMap, aLats, aLngs)
    {
        this.mMap = aMap;
        this.mLatLngList = toLatLngs(aLats || [], aLngs || []);
        this.mExtraPolylines = [];
        this.mBackgroundPolylines = [];
        this.mSegmentLatLngList = [];

        var bounds = makeBounds(this.mLatLngList);
        this.mBounds = bounds;

        this.mPolyline = L.polyline(this.mLatLngList, {
            color: "black", weight: 4, opacity: 1, clickable: false
        });
        this.mSegmentPolyline = L.polyline([], {
            color: "black", weight: 4, opacity: 1, clickable: false
        });

        var markerIcon, startIcon, endIcon;
        try
        {
            markerIcon = L.icon({
                iconUrl: "../images/marker.png",
                iconSize: [50, 50],
                iconAnchor: [26, 26]
            });
        }
        catch (e) { markerIcon = new L.Icon.Default(); }
        try
        {
            startIcon = L.icon({
                iconUrl: "../images/start.png",
                iconSize: [15, 15],
                iconAnchor: [8, 8]
            });
        }
        catch (e) { startIcon = new L.Icon.Default(); }
        try
        {
            endIcon = L.icon({
                iconUrl: "../images/end.png",
                iconSize: [28, 28],
                iconAnchor: [14, 14]
            });
        }
        catch (e) { endIcon = new L.Icon.Default(); }

        this.mMarkerIcon = markerIcon;
        this.mStartIcon = startIcon;
        this.mEndIcon = endIcon;

        var first = this.mLatLngList.length > 0 ? this.mLatLngList[0] : L.latLng(0, 0);
        var last = this.mLatLngList.length > 0 ? this.mLatLngList[this.mLatLngList.length - 1] : L.latLng(0, 0);

        this.mMarker = L.marker(first, { icon: markerIcon, draggable: true, clickable: false, zIndexOffset: 1000 });
        this.mStartMarker = L.marker(first, { icon: startIcon, draggable: false, clickable: false });
        this.mEndMarker = L.marker(last, { icon: endIcon, draggable: false, clickable: false });
        this.mLastPos = first;
        this.mAdded = { track: false, segment: false, marker: false, start: false, end: false };

        var that = this;
        this.mMarker.on("dragstart", function () { try { DragStarted(); } catch (e) {} });
        this.mMarker.on("dragend", function () { try { DragEnded(); } catch (e) {} });
        this.mMarker.on("drag", function (e)
        {
            try
            {
                var ll = that.mMarker.getLatLng();
                var res = null;
                try { res = GetClosestPositionOnTrack(ll.lat, ll.lng); } catch (err2) { res = null; }
                if (res)
                {
                    var arr = null;
                    try { arr = $.parseJSON(res); } catch (err3) { arr = null; }
                    if (arr && arr.length >= 2)
                    {
                        var np = L.latLng(arr[0], arr[1]);
                        that.mLastPos = np;
                        that.mMarker.setLatLng(np);
                    }
                    else
                    {
                        that.mMarker.setLatLng(that.mLastPos);
                    }
                }
                else
                {
                    that.mLastPos = ll;
                }
                try { MarkerPositionChanged(that.mLastPos.lat, that.mLastPos.lng); } catch (err4) {}
            }
            catch (err) { try { console.log(err.toString()); } catch (e2) {} }
        });

        if (bounds && this.mMap)
        {
            try { this.mMap.fitBounds(bounds); } catch (e) {}
        }
    }

    Track.prototype._ensureOnMap = function (layer, key)
    {
        if (!this.mMap || !layer) { return; }
        if (!this.mAdded[key])
        {
            try { layer.addTo(this.mMap); this.mAdded[key] = true; } catch (e) {}
        }
    };

    Track.prototype._removeFromMap = function (layer, key)
    {
        if (!this.mMap || !layer) { return; }
        try
        {
            if (this.mMap.hasLayer(layer)) { this.mMap.removeLayer(layer); }
            if (key) { this.mAdded[key] = false; }
        }
        catch (e) {}
    };

    Track.prototype.AddTrack = function (aLats, aLngs)
    {
        var list = toLatLngs(aLats, aLngs);
        if (list.length === 0) { return; }
        this.mLatLngList = this.mLatLngList.concat(list);
        this.mBounds = makeBounds(this.mLatLngList);
        var pl = L.polyline(list, { color: "black", weight: 4, opacity: 1, clickable: false });
        try { pl.addTo(this.mMap); } catch (e) {}
        this.mExtraPolylines.push(pl);
        try { if (this.mBounds) { this.mMap.fitBounds(this.mBounds); } } catch (e) {}
        try { this.mEndMarker.setLatLng(list[list.length - 1]); } catch (e) {}
    };

    Track.prototype.UpdateTrack = function (aLats, aLngs)
    {
        var i;
        for (i = 0; i < this.mExtraPolylines.length; i++)
        {
            try { this.mMap.removeLayer(this.mExtraPolylines[i]); } catch (e) {}
        }
        this.mExtraPolylines = [];
        this.ClearBackgroundTracks();
        this.mLatLngList = toLatLngs(aLats, aLngs);
        this.mBounds = makeBounds(this.mLatLngList);
        try { this.mPolyline.setLatLngs(this.mLatLngList); } catch (e) {}
        if (this.mLatLngList.length > 0)
        {
            try
            {
                this.mStartMarker.setLatLng(this.mLatLngList[0]);
                this.mEndMarker.setLatLng(this.mLatLngList[this.mLatLngList.length - 1]);
            }
            catch (e) {}
            this.mLastPos = this.mLatLngList[0];
        }
        try { if (this.mBounds) { this.mMap.fitBounds(this.mBounds); } } catch (e) {}
    };

    Track.prototype.SetSegment = function (aLats, aLngs)
    {
        var list = toLatLngs(aLats, aLngs);
        this.mSegmentLatLngList = list;
        try { this.mPolyline.setStyle({ color: "gray" }); } catch (e) {}
        try
        {
            this.mSegmentPolyline.setLatLngs(list);
            if (!this.mMap.hasLayer(this.mSegmentPolyline)) { this.mSegmentPolyline.addTo(this.mMap); }
            this.mAdded.segment = true;
        }
        catch (e) {}
    };

    Track.prototype.ClearSegment = function ()
    {
        this.mSegmentLatLngList = [];
        try { this._removeFromMap(this.mSegmentPolyline, "segment"); } catch (e) {}
        try { this.mPolyline.setStyle({ color: "black" }); } catch (e) {}
    };

    Track.prototype.AddBackgroundTrack = function (aLats, aLngs)
    {
        var list = toLatLngs(aLats, aLngs);
        if (list.length === 0) { return; }
        // extend bounds
        var i;
        var all = this.mLatLngList.concat(list);
        for (i = 0; i < this.mBackgroundPolylines.length; i++)
        {
            try
            {
                var ll = this.mBackgroundPolylines[i].getLatLngs();
                if (ll && ll.length) { all = all.concat(ll); }
            }
            catch (e) {}
        }
        this.mBounds = makeBounds(all);
        var pl = L.polyline(list, { color: "gray", weight: 4, opacity: 1, clickable: false });
        try { pl.addTo(this.mMap); } catch (e) {}
        this.mBackgroundPolylines.push(pl);
        try { if (this.mBounds) { this.mMap.fitBounds(this.mBounds); } } catch (e) {}
    };

    Track.prototype.ClearBackgroundTracks = function ()
    {
        var i;
        for (i = 0; i < this.mBackgroundPolylines.length; i++)
        {
            try { this.mMap.removeLayer(this.mBackgroundPolylines[i]); } catch (e) {}
        }
        this.mBackgroundPolylines = [];
    };

    Track.prototype.SetMarkerPosition = function (aLat, aLon)
    {
        var p = L.latLng(aLat, aLon);
        this.mLastPos = p;
        try
        {
            if (!this.mMap.hasLayer(this.mMarker)) { this.mMarker.addTo(this.mMap); this.mAdded.marker = true; }
            this.mMarker.setLatLng(p);
        }
        catch (e) {}
        try
        {
            var b = null;
            try { b = this.mMap.getBounds(); } catch (e2) { b = null; }
            if (b && !b.contains(p)) { this.mMap.panTo(p); }
        }
        catch (e) {}
    };

    Track.prototype.HideMarker = function ()
    {
        this._removeFromMap(this.mMarker, "marker");
    };

    Track.prototype.ShowTrack = function ()
    {
        try { if (this.mBounds) { this.mMap.fitBounds(this.mBounds); } } catch (e) {}
        this._ensureOnMap(this.mPolyline, "track");
        this._ensureOnMap(this.mStartMarker, "start");
        this._ensureOnMap(this.mEndMarker, "end");
        var i;
        for (i = 0; i < this.mExtraPolylines.length; i++)
        {
            try { if (!this.mMap.hasLayer(this.mExtraPolylines[i])) { this.mExtraPolylines[i].addTo(this.mMap); } } catch (e) {}
        }
    };

    Track.prototype.HideTrack = function ()
    {
        this._removeFromMap(this.mPolyline, "track");
        this._removeFromMap(this.mMarker, "marker");
        this._removeFromMap(this.mStartMarker, "start");
        this._removeFromMap(this.mEndMarker, "end");
        var i;
        for (i = 0; i < this.mExtraPolylines.length; i++)
        {
            try { this.mMap.removeLayer(this.mExtraPolylines[i]); } catch (e) {}
        }
    };

    Track.prototype.SetMarkerDraggable = function (canDrag)
    {
        try
        {
            if (this.mMarker.dragging)
            {
                if (canDrag) { this.mMarker.dragging.enable(); }
                else { this.mMarker.dragging.disable(); }
            }
            else
            {
                try { this.mMarker.options.draggable = !!canDrag; } catch (e) {}
            }
        }
        catch (e) {}
    };

    return Track;
})();

function findClosest(latLng, latLngList)
{
    // IE-compatible fallback: linear search, degrees (no geometry lib)
    if (!latLngList || latLngList.length === 0) { return latLng; }
    var best = latLngList[0];
    var bestD = 1e12;
    var i, d, p;
    for (i = 0; i < latLngList.length; i++)
    {
        p = latLngList[i];
        d = (p.lat - latLng.lat) * (p.lat - latLng.lat) + (p.lng - latLng.lng) * (p.lng - latLng.lng);
        if (d < bestD) { bestD = d; best = p; }
    }
    return best;
}
