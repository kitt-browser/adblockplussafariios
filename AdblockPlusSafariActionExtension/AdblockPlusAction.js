var AdblockPlusAction = function() {};

AdblockPlusAction.prototype =
{
  run: function(arguments)
  {
    // Pass the baseURI of the webpage to the extension.
    arguments.completionFunction({"baseURI": document.baseURI});
  }
};

// The JavaScript file must contain a global object named "ExtensionPreprocessingJS".
var ExtensionPreprocessingJS = new AdblockPlusAction();

