{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.zed-editor.enable {
    home.packages = with pkgs; [
      cmake
      ninja
    ];

    programs.zed-editor = {
      extensions = [
        "cmake"
      ];

      userTasks = [
        {
          label = "cmake build all";
          command = "cmake --build build";
          use_new_terminal = false;
          reveal = "always";
        }
        {
          label = "cmake configure";
          command = "cmake -B build -G Ninja";
          use_new_terminal = false;
          reveal = "always";
        }
      ];
    };
  };
}
