require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'


configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def todos_count(list)
    list[:todos].size
  end
  
  def todos_remaining(list)
    total = 0
    list[:todos].each { |todo| total += 1 if todo[:completed] == true }
    todos_count(list) - total
  end

  def list_completed?(todos)
    todos.all? { |todo| todo[:completed] == true } && todos.size >= 1
  end

  def list_class(list)
    "complete" if list_completed?(list[:todos])
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list[:todos]) }

    incomplete_lists.each { |list| yield list, lists.index(list) }    
    complete_lists.each { |list| yield list, lists.index(list) }  
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block) 
  end
  
  def h(contents)
    Rack::Utils.escape_html(contents)
  end
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

# Return an error message if the todo name is invalid
def error_for_todo_list(name, todos)
  if !(1..100).cover?(name.size)
    'Todo must be between 1 and 100 characters.'
  end
end

# Confirm requested list exists and display error if not
def load_list(id)
  all_lists = session[:lists]
  list = all_lists.find { |list| list[:id] == id }
  
  #list = session[:lists][index] if index && session[:lists][index]
  return list if list
  
  session[:error] = "The specified list was not found."
  redirect '/lists'
end

def get_next_list_id(lists)
  max = lists.map { |list| list[:id] }.max || 0
  max + 1
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  id = get_next_list_id(session[:lists])

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end
  
# View a single list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Render the Edit list name for
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  @current_name = session[:lists].find { |list| list[:id] == id }
  
  #@current_name = session[:lists][id][:name]
  
  erb :edit_list, layout: :layout
end

# Edit the list name
post '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)
  new_list_name = params[:new_list_name].strip
  list = session[:lists].find { |list| list[:id] == id }
  
  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
   list[:name] = new_list_name
   #session[:lists][id][:name] = new_list_name
   session[:success] = "The list has been renamed #{new_list_name}"
   redirect "/lists/#{id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do
  id = params[:id].to_i
  @list = load_list(id)
  
  session[:lists].reject! { |list| list[:id] == id }
  
  #deleted_list = session[:lists].delete_at(id)
  
    #check to see if request beig sent via AJAX
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted"
    redirect '/lists'
  end
end

# Add a todo item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo_item].strip
  
  error = error_for_todo_list(todo_name, @list[:todos])
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: todo_name, completed: false }
    
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Remove a todo item from the list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @todos = load_list(@list_id)[:todos]
  
  @todos.reject! { |todo| todo[:id] == @todo_id }
  #deleted_todo = @todos.delete_at(@todo_id)
  
  #check to see if request beig sent via AJAX
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 # says there is no content
  else
    session[:success] = "The todo was successfully deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Toggle the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true" 
  
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  #@list[:todos][todo_id][:completed] = is_completed

  session[:success] = "Todo has been updated"
  redirect "/lists/#{@list_id}"
end

# Complete all todo tasks
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todo's have been marked as completed"
  redirect "/lists/#{@list_id}"
end

