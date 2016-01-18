from mc.core.config_player import ConfigPlayer


class SlidePlayer(ConfigPlayer):
    config_file_section = 'slide_player'

    def play(self, settings, mode=None):
        try:
            if not mode.active:
                return
        except AttributeError:
            pass

        for s in settings:  # settings is a list of one or more slide configs

            name = s['slide']

            if s['target']:
                target = self.mc.targets[s['target']]

            elif mode:
                target = mode.target
            else:
                target = self.mc.targets['default']

            # if the slide already exists and is not active, show it
            if not target.show_slide(name, s['force']):
                try:
                    priority = s['priority']
                except KeyError:
                    priority = 0

                config = self.mc.slide_configs[name]

                target.add_slide(name=name, config=config,
                                 show=s['show'], force=s['force'],
                                 priority=priority, mode=mode)
