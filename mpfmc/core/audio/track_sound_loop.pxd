from mpfmc.core.audio.sdl2 cimport *
from mpfmc.core.audio.gstreamer cimport *
from mpfmc.core.audio.sound_file cimport *
from mpfmc.core.audio.track cimport *
from mpfmc.core.audio.notification_message cimport *


# ---------------------------------------------------------------------------
#    Sound Loop Track types
# ---------------------------------------------------------------------------

cdef enum LayerStatus:
    layer_stopped = 0
    layer_playing = 1
    layer_fading_in = 2
    layer_fading_out = 3

ctypedef struct SoundLoopLayerSettings:
    LayerStatus status
    SoundSample *sound
    Uint8 volume
    long sound_id
    Uint32 fade_in_steps
    Uint32 fade_out_steps
    Uint32 fade_steps_remaining
    Uint8 marker_count
    GArray *markers

cdef enum SoundLoopSetPlayerStatus:
    # Enumeration of the possible sound loop set player status values.
    player_idle = 0
    player_pending = 1
    player_replacing = 2
    player_fading_in = 3
    player_fading_out = 4
    player_playing = 5
    player_finished = 6
    player_stopping = 7

ctypedef struct SoundLoopSetPlayer:
    SoundLoopSetPlayerStatus status
    GSList *layers     # An array of SoundLoopLayerSettings objects
    Uint32 sample_pos
    Uint32 fade_in_steps
    Uint32 fade_out_steps
    Uint32 fade_steps_remaining
    bint synchronize_with_other_player

ctypedef struct TrackSoundLoopState:
    # State variables for TrackSoundLoop tracks
    SoundLoopSetPlayer player_1
    SoundLoopSetPlayer player_2
    SoundLoopSetPlayer *current
    SoundLoopSetPlayer *next


# ---------------------------------------------------------------------------
#    TrackSoundLoop class
# ---------------------------------------------------------------------------
cdef class TrackSoundLoop(Track):

    # Track state needs to be stored in a C struct in order for them to be accessible in
    # the SDL callback functions without the GIL (for performance reasons).
    # The TrackSoundLoopState struct is allocated during construction and freed during
    # destruction.
    cdef TrackSoundLoopState *type_state

    cdef _initialize_player(self, SoundLoopSetPlayer *player)
    cdef _reset_player_layers(self, SoundLoopSetPlayer *player)

    @staticmethod
    cdef void mix_playing_sounds(TrackState *track, Uint32 buffer_length, AudioCallbackData *callback_data) nogil


cdef inline SoundLoopLayerSettings *_create_sound_loop_layer_settings() nogil