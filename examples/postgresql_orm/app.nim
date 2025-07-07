# PostgreSQL ORM Example for Prologue
# 
# This example demonstrates how to use the new PostgreSQL ORM system
# with basic CRUD operations and model definitions.

import std/[asyncdispatch, json, logging, strutils]
import prologue
import ../../src/prologue/db/orm/[orm, model]
import ../../src/prologue/db/orm/postgres/types

# Configure logging
addHandler(newConsoleLogger(fmtStr="[$time] - $levelname: "))
setLogFilter(lvlDebug)

# Define User model
type
  User* = ref object of Model
    username*: string
    email*: string
    fullName*: string
    isActive*: bool
    createdAt*: string  # Would be DateTime in full implementation

# Define Post model  
type
  Post* = ref object of Model
    title*: string
    content*: string
    authorId*: int
    publishedAt*: string  # Would be DateTime in full implementation

# Initialize models (simplified registration)
proc initModels(orm: ORM) =
  # In full implementation, this would use macros for automatic registration
  let userMeta = defineModel(
    "User",
    "users", 
    "id",
    field(id, int, pgPrimaryKey, pgSerial),
    field(username, string, pgUnique, pgNotNull),
    field(email, string, pgUnique, pgNotNull),
    field(fullName, string),
    field(isActive, bool, pgDefault),
    field(createdAt, string, pgDefault)
  )
  
  let postMeta = defineModel(
    "Post",
    "posts",
    "id", 
    field(id, int, pgPrimaryKey, pgSerial),
    field(title, string, pgNotNull),
    field(content, string),
    field(authorId, int, pgForeignKey),
    field(publishedAt, string)
  )
  
  orm.registerModel(userMeta)
  orm.registerModel(postMeta)

# API Handlers
proc createUser(ctx: Context) {.async.} =
  try:
    let data = ctx.request.body.parseJson()
    
    # Create new user
    let user = User()
    user.username = data["username"].getStr()
    user.email = data["email"].getStr()
    user.fullName = data.getOrDefault("fullName").getStr("")
    user.isActive = data.getOrDefault("isActive").getBool(true)
    user.createdAt = "now()"  # Would use proper DateTime
    
    await user.save()
    
    resp jsonResponse(%{
      "success": %true,
      "message": %"User created successfully",
      "user": user.toJson()
    })
    
  except Exception as e:
    logging.error("Error creating user: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc getUser(ctx: Context) {.async.} =
  try:
    let userId = ctx.getPathParams("id").parseInt()
    let user = await User.objects.get(userId)
    
    resp jsonResponse(%{
      "success": %true,
      "user": user.toJson()
    })
    
  except ModelError as e:
    resp jsonResponse(%{
      "success": %false,
      "error": %"User not found"
    }, Http404)
  except Exception as e:
    logging.error("Error getting user: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc getAllUsers(ctx: Context) {.async.} =
  try:
    let users = await User.objects.all()
    let usersJson = newJArray()
    
    for user in users:
      usersJson.add(user.toJson())
    
    resp jsonResponse(%{
      "success": %true,
      "users": usersJson,
      "count": %users.len
    })
    
  except Exception as e:
    logging.error("Error getting users: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc updateUser(ctx: Context) {.async.} =
  try:
    let userId = ctx.getPathParams("id").parseInt()
    let data = ctx.request.body.parseJson()
    
    let user = await User.objects.get(userId)
    
    # Update fields
    if data.hasKey("username"):
      user.username = data["username"].getStr()
      user.markDirty()
    
    if data.hasKey("email"):
      user.email = data["email"].getStr()
      user.markDirty()
    
    if data.hasKey("fullName"):
      user.fullName = data["fullName"].getStr()
      user.markDirty()
    
    if data.hasKey("isActive"):
      user.isActive = data["isActive"].getBool()
      user.markDirty()
    
    await user.save()
    
    resp jsonResponse(%{
      "success": %true,
      "message": %"User updated successfully",
      "user": user.toJson()
    })
    
  except ModelError as e:
    resp jsonResponse(%{
      "success": %false,
      "error": %"User not found"
    }, Http404)
  except Exception as e:
    logging.error("Error updating user: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc deleteUser(ctx: Context) {.async.} =
  try:
    let userId = ctx.getPathParams("id").parseInt()
    let user = await User.objects.get(userId)
    
    await user.delete()
    
    resp jsonResponse(%{
      "success": %true,
      "message": %"User deleted successfully"
    })
    
  except ModelError as e:
    resp jsonResponse(%{
      "success": %false,
      "error": %"User not found"
    }, Http404)
  except Exception as e:
    logging.error("Error deleting user: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc createPost(ctx: Context) {.async.} =
  try:
    let data = ctx.request.body.parseJson()
    
    # Verify author exists
    let authorId = data["authorId"].getInt()
    let authorExists = await User.objects.exists(authorId)
    if not authorExists:
      resp jsonResponse(%{
        "success": %false,
        "error": %"Author not found"
      }, Http400)
      return
    
    # Create new post
    let post = Post()
    post.title = data["title"].getStr()
    post.content = data["content"].getStr()
    post.authorId = authorId
    post.publishedAt = "now()"  # Would use proper DateTime
    
    await post.save()
    
    resp jsonResponse(%{
      "success": %true,
      "message": %"Post created successfully",
      "post": post.toJson()
    })
    
  except Exception as e:
    logging.error("Error creating post: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc getPostsByUser(ctx: Context) {.async.} =
  try:
    let userId = ctx.getPathParams("userId").parseInt()
    
    # Verify user exists
    let userExists = await User.objects.exists(userId)
    if not userExists:
      resp jsonResponse(%{
        "success": %false,
        "error": %"User not found"
      }, Http404)
      return
    
    # Get posts by user (simplified query)
    let posts = await Post.objects.all("author_id = $1", @[$userId])
    let postsJson = newJArray()
    
    for post in posts:
      postsJson.add(post.toJson())
    
    resp jsonResponse(%{
      "success": %true,
      "posts": postsJson,
      "count": %posts.len
    })
    
  except Exception as e:
    logging.error("Error getting posts: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc testConnection(ctx: Context) {.async.} =
  try:
    let orm = getORM()
    let connected = await orm.testConnection()
    
    resp jsonResponse(%{
      "success": %true,
      "connected": %connected,
      "database": %orm.config.database
    })
    
  except Exception as e:
    logging.error("Error testing connection: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

proc databaseStats(ctx: Context) {.async.} =
  try:
    let userCount = await User.objects.count()
    let postCount = await Post.objects.count()
    
    resp jsonResponse(%{
      "success": %true,
      "stats": %{
        "users": %userCount,
        "posts": %postCount
      }
    })
    
  except Exception as e:
    logging.error("Error getting stats: " & e.msg)
    resp jsonResponse(%{
      "success": %false,
      "error": %e.msg
    }, Http500)

# Main application
proc main() {.async.} =
  # Initialize ORM
  logging.info("Initializing PostgreSQL ORM...")
  let orm = await initExampleORM()
  
  # Initialize models
  initModels(orm)
  
  # Sync database (create tables if they don't exist)
  await orm.syncDatabase()
  
  # Create Prologue app
  let app = newApp()
  
  # ORM is already initialized globally
  logging.info("ORM ready for use")
  
  # Routes
  app.get("/", proc(ctx: Context) {.async.} =
    resp htmlResponse("""
    <h1>PostgreSQL ORM Example</h1>
    <h2>Available endpoints:</h2>
    <ul>
      <li>GET /test - Test database connection</li>
      <li>GET /stats - Database statistics</li>
      <li>GET /users - Get all users</li>
      <li>POST /users - Create user</li>
      <li>GET /users/{id} - Get user by ID</li>
      <li>PUT /users/{id} - Update user</li>
      <li>DELETE /users/{id} - Delete user</li>
      <li>POST /posts - Create post</li>
      <li>GET /users/{userId}/posts - Get posts by user</li>
    </ul>
    """))
  
  app.get("/test", testConnection)
  app.get("/stats", databaseStats)
  
  # User routes
  app.get("/users", getAllUsers)
  app.post("/users", createUser)
  app.get("/users/{id}", getUser)
  app.put("/users/{id}", updateUser)
  app.delete("/users/{id}", deleteUser)
  
  # Post routes
  app.post("/posts", createPost)
  app.get("/users/{userId}/posts", getPostsByUser)
  
  logging.info("Starting server on http://localhost:8080")
  app.run()

when isMainModule:
  waitFor main()