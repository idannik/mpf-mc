from mpfmc.core.audio.sdl2 cimport *
from mpfmc.core.audio.gstreamer cimport *
from mpfmc.core.audio.track cimport TrackState


# ---------------------------------------------------------------------------
#    Notification Message types
# ---------------------------------------------------------------------------

cdef enum NotificationMessage:
    notification_sound_started = 1            # Notification that a sound has started playing
    notification_sound_stopped = 2            # Notification that a sound has stopped
    notification_sound_looping = 3            # Notification that a sound is looping back to the beginning
    notification_sound_marker = 4             # Notification that a sound marker has been reached
    notification_sound_about_to_finish = 5    # Notification that a sound is about to finish playing
    notification_player_idle = 10             # Notification that a player is now idle and ready to play another sound
    notification_track_stopped = 0            # Notification that the track has stopped
    notification_track_paused = 21            # Notification that the track has been paused

ctypedef struct NotificationMessageDataLooping:
    int loop_count
    int loops_remaining

ctypedef struct NotificationMessageDataMarker:
    int id

ctypedef union NotificationMessageData:
    NotificationMessageDataLooping looping
    NotificationMessageDataMarker marker

ctypedef struct NotificationMessageContainer:
    NotificationMessage message
    long sound_id
    long sound_instance_id
    int player
    NotificationMessageData data


# ---------------------------------------------------------------------------
#    Notification Message functions
# ---------------------------------------------------------------------------

cdef inline NotificationMessageContainer *_create_notification_message() nogil:
    """
    Creates a new notification message.
    :return: A pointer to the new notification message.
    """
    return <NotificationMessageContainer*>g_slice_alloc0(sizeof(NotificationMessageContainer))

cdef inline void send_sound_started_notification(int player, long sound_id, long sound_instance_id,
                                                 TrackState *track) nogil:
    """
    Sends a sound started notification
    Args:
        player: The sound player number on which the event occurred
        sound_id: The sound id
        sound_instance_id: The sound instance id
        track: The TrackState pointer
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_sound_started
        notification_message.player = player
        notification_message.sound_id = sound_id
        notification_message.sound_instance_id = sound_instance_id

        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)

cdef inline void send_sound_stopped_notification(int player, long sound_id, long sound_instance_id,
                                                 TrackState *track) nogil:
    """
    Sends a sound stopped notification
    Args:
        player: The sound player number on which the event occurred
        sound_id: The sound id
        sound_instance_id: The sound instance id
        track: The TrackState pointer
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_sound_stopped
        notification_message.player = player
        notification_message.sound_id = sound_id
        notification_message.sound_instance_id = sound_instance_id

        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)

cdef inline void send_sound_looping_notification(int player, long sound_id, long sound_instance_id,
                                                 TrackState *track) nogil:
    """
    Sends a sound looping notification
    Args:
        player: The sound player number on which the event occurred
        sound_id: The sound id
        sound_instance_id: The sound instance id
        track: The TrackState pointer
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_sound_looping
        notification_message.player = player
        notification_message.sound_id = sound_id
        notification_message.sound_instance_id = sound_instance_id

        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)

cdef inline void send_sound_marker_notification(int player, long sound_id, long sound_instance_id,
                                                TrackState *track,
                                                int marker_id) nogil:
    """
    Sends a sound marker notification message
    Args:
        player: The sound player number on which the event occurred
        sound_id: The sound id
        sound_instance_id: The sound instance id
        track: The TrackState pointer
        marker_id: The id of the marker being sent for the specified sound
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_sound_marker
        notification_message.player = player
        notification_message.sound_id = sound_id
        notification_message.sound_instance_id = sound_instance_id
        notification_message.data.marker.id = marker_id

        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)

cdef inline void send_track_stopped_notification(TrackState *track) nogil:
    """
    Sends a track stopped notification
    Args:
        track: The TrackState pointer
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_track_stopped
        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)

cdef inline void send_track_paused_notification(TrackState *track) nogil:
    """
    Sends a track paused notification
    Args:
        track: The TrackState pointer
    """
    cdef NotificationMessageContainer *notification_message = _create_notification_message()
    if notification_message != NULL:
        notification_message.message = notification_track_paused
        track.notification_messages = g_slist_prepend(track.notification_messages, notification_message)
