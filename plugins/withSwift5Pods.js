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
      // Remove any existing SWIFT_VERSION patch
      contents = contents.replace(/\n\s*installer\.pods_project\.targets\.each do \|target\|[\s\S]*?end\n/g, '\n');
      // Insert AFTER react_native_post_install block, before end of post_install
      contents = contents.replace(
        /(\s*react_native_post_install\([\s\S]*?\)\s*\n)(\s*end\s*\nend)/,
        `$1${patch}\n$2`
      );
      fs.writeFileSync(podfile, contents);
      return cfg;
    },
  ]);
