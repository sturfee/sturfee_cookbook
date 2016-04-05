require 'chefspec'
# require 'chefspec/berkshelf'
require 'chefspec/librarian'

ChefSpec::Coverage.start!

def puts! args, label=""
  puts "+++ +++ #{label}"
  puts args.inspect
end
