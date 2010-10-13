Command implementation on destination server
============================================

A command is placed in the directory '$REMOPSHOME/remops/roles/<role>/cmd'.

A command must have the executable bit set for the remops user.

A command may be a script or a binary.

The arguments to the command may be read from the environment variable SSH_ORIGINAL_COMMAND.

If a command needs specific SSH options set by the client it may implement a sibling command the is named the same but postfixed with "-options". A command named 'dosomething' may the have a sibling command 'dosomething-options" that writes SSH options on stdout.


