const { withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

module.exports = (config) =>
  withDangerousMod(config, [
    'ios',
    (cfg) => {
      const podfile = path.join(cfg.modRequest.platformProjectRoot, 'Podfile');
      let contents = fs.readFileSync(podfile, 'utf8');
      const patch = `
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5.9'
    end
  end`;
      if (!contents.includes("SWIFT_VERSION") && contents.includes('post_install do |installer|')) {
        contents = contents.replace(
          'post_install do |installer|',
          `post_install do |installer|\n${patch}`
        );
        fs.writeFileSync(podfile, contents);
      }
      return cfg;
    },
  ]);
