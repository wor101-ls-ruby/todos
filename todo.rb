require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET /lists        -> view all lists
# GET /lists/new    -> new list form
# POST /lists       -> create new list
# GET /lists/1      -> view a single list

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Return an error message if the name is invalid
def error_for_todo_list(name, todos)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif todos.any? { |todo| todo == name }
    'List name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end
  
# View a single list
get '/lists/:id' do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :list, layout: :layout
end

# Render the Edit list name for
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]
  @current_name = session[:lists][id][:name]
  
  erb :edit_list, layout: :layout
end

# Edit the list name
post '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]
  new_list_name = params[:new_list_name].strip
  
  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
   session[:lists][id][:name] = new_list_name
   session[:success] = "The list has been renamed #{new_list_name}"
   redirect "/lists/#{id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do
  id = params[:id].to_i
  @list = session[:lists][id]
  
  deleted_list = session[:lists].delete_at(id)
  session[:success] = "The #{deleted_list[:name]} list has been deleted"
  redirect '/lists'
end

# Add a todo item
post '/lists/:id/todos' do
  id = params[:id].to_i
  @list = session[:lists][id]
  todo_item = params[:todo_item].strip
  
  error = error_for_todo_list(todo_item, @list[:todos])
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << todo_item
    redirect "/lists/#{id}"
  end
end