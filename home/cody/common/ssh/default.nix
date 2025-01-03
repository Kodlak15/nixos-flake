{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      github = {
        hostname = "github.com";
        user = "git";
      };
      pwncollege = {
        hostname = "dojo.pwn.college";
        identityFile = "/home/cody/.ssh/pwn";
        user = "hacker";
      };
      cyrodil = {
        hostname = "peckspaintingmt.com";
        identityFile = "/home/cody/.ssh/cyrodil";
      };
      codeberg = {
        hostname = "codeberg.org";
        user = "git";
      };
      elsweyr = {
        hostname = "cascadewebservices.org";
        user = "cody";
      };
      morrowind = {
        hostname = "cascade-botanicals.com";
        user = "root";
      };
    };
  };
}
