//External API Callbacks
function
DragStarted()
{
    try
    {
        if( window.external )
        {
            window.external.DragStartHandler();
        }
        else
        {
            console.DragStartHandler();
        }
    }
    catch( err )
    {
    }
}

function
DragEnded()
{
    try
    {
        if( window.external )
        {
            window.external.DragEndHandler();
        }
        else
        {
            console.DragEndHandler();
        }
    }
    catch( err )
    {
    }
}

//----------------------------------------------------------------------------
// Asks the application for the closest position on the track to the given lat/lon
//
// @param aLat  a latitude to where the mouse has been dragged
// @param aLon  a longitude to where the mouse has been dragged
// @return the closest lat/lon on the track to the params
function
GetClosestPositionOnTrack( aLat, aLon )
{
    try
    {
        if( window.external )
        {
            return window.external.GetClosestPositionOnTrack( aLat, aLon );
        }
        else
        {
            return console.GetClosestPositionOnTrack( aLat, aLon );
        }
    }
    catch( err )
    {
        console.log( err.toString() );
    }
}

//----------------------------------------------------------------------------
// Notifies the application that the marker position has been changed
//
// @param aLat  the latitude of where the marker now is
// @param aLon  the longitude of where the marker now is
function
MarkerPositionChanged( aLat, aLon )
{
    try
    {
        if( window.external )
        {
            return window.external.MarkerPositionChanged( aLat, aLon );
        }
        else
        {
            return console.MarkerPositionChanged( aLat, aLon );
        }
    }
    catch( err )
    {
        console.log( err.toString() );
    }
}

function
MapTypeChanged( aMap )
{
    try
    {
        if( window.external )
        {
            window.external.MapTypeChanged( aMap );
        }
        else
        {
            console.MapTypeChanged( aMap );
        }
    }
    catch( err )
    {
    }
}

function
MapDidInitialize()
{
    try
    {
        if( window.external )
        {
            window.external.MapDidInitialize();
        }
        else
        {
            console.MapDidInitialize();
        }
    }
    catch( err )
    {
    }
}


//External Public API
function
SetTrack( aLatList, aLngList )
{
    SetTrackImpl( aLatList, aLngList );
}

// This needs to be a subset of the Track
// or else things will not work correctly.
// It isn't strictly enforced by the JS, however.
function
SetTrackSegment( aLatList, aLngList )
{
    SetTrackSegmentImpl( aLatList, aLngList );
}

function
ClearTrackSegment()
{
    if( !mTrack )
    {
        return;
    }
    else
    {
        mTrack.ClearSegment();
    }
}

function
AddTrack( aLatList, aLngList )
{
    AddTrackImpl( aLatList, aLngList );
}

function
ShowTrack()
{
    if( !mTrack )
    {
        return;
    }

    mTrack.ShowTrack();
}

function
AddBackgroundTrack( aLatList, aLngList )
{
    AddBackgroundTrackImpl( aLatList, aLngList );
}

function
ClearBackgroundTracks()
{
    if( !mTrack )
    {
        return;
    }

    mTrack.ClearBackgroundTracks();
}

function
SetMarkerPosition( aLat, aLon )
{
    SetMarkerPositionImpl( aLat, aLon );
}

function
HideMarker()
{
    if( !mTrack )
    {
        return;
    }

    mTrack.HideMarker();
}

function
HideTrack()
{
    if( !mTrack )
    {
        return;
    }

    mTrack.HideTrack();
}

function
SetMarkerDraggable( aYesNo )
{
    if( !mTrack )
    {
        return;
    }

    mTrack.SetMarkerDraggable( aYesNo );
}

function
SetMapControlTitles( aMapTitle, aRoad, aBirdsEye )
{
    SetMapControlTitlesInternal( aMapTitle, aRoad, aBirdsEye );
}

function
SetMapType( aMapType )
{
    SetMapTypeInternal( aMapType );
}