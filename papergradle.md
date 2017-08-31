About PaperGradle
=================

Paper is hopefully moving from Spigot's horrendously awful mappings to instead use MCP mappings in the dev workspace, and SRG mappings in the
production environment, to allow easier development of Paper and better stability for any plugins which interact with core Minecraft code and
would like to use our mappings.

In case there's any reason you need proof of how much better MCP is over Spigot's mappings, compare the
[WorldData](http://i.imgur.com/3WzBBmA.png) class in Spigot to the [WorldInfo](http://imgur.com/gguHtmD.png) class in MCP. These are both the
same class, just mapped differently. I think it should be rather clear why we would want to use MCP mappings in our dev environment if
possible. This page will hopefully try to explain how we managed to make this work, and give insight on how to deal with the different
issues which will inevitably pop up when pulling in new Spigot changes, or updating to new versions of Minecraft.

Task Descriptions
-----------------

These are the custom tasks that are in `PaperGradle`, and how to interact with them.

 * ### `mcpRewrites`:

    This task fixes name clashing issues between Spigot and MCP. For example, in `MinecraftServer`, Spigot has added a field of type
    `List<WorldServer>` called `worlds`. There is field already present in `MinecraftServer` of type `WorldServer[]`, which in Spigot isn't
    mapped to any particular name, but in MCP is mapped correctly to the name `worlds`. After a remap operation to MCP, these names will
    obviously clash and cause issues. It is important to remember that these MCP mapped names will only exist in the development workspace,
    as the `reobfuscate` task will remap everything back to SRG. This lets us easily define our own MCP names for SRG members without
    affecting the output jar.
    
    This action is done in the `mcpRewrites` task. It reads the `mcp/mcp-rewrites.txt` file. Before the `genSrgs` task runs, which takes as
    input the MCP CSV files and outputs the SRG files used in the remap process, we modify the CSV files and create our own Paper-mappings.
    This only modifies the MCP names, not the SRG names. The format is quite simple:
    
    `field_71305_c,mcpWorlds`
    
    The SRG name of the field, method, or parameter, followed by the MCP name we want to use instead. Here instead of `worlds` we call it
    `mcpWorlds` to disambiguate between this field and the Spigot-added field.

 * ### `genSpigotSrgs`:

    This task is essential to our build process. This task takes as input the SRG files created from the `genSrgs` task, as well as the
    CSRG files Spigot uses, and creates SRG mappings to and from SRG and Spigot, and to and from MCP and Spigot. This is how we are able to
    accomplish this at all. This task is totally automated from the `genSrgs` task, so it really shouldn't require any fiddling
    with during Minecraft version upgrades.

 * ### `decompileVanillaJar`:
 
    It does what it sounds like, but the key here is it uses Spigot's FernFlower and Spigot's FernFlower settings. This is necessary for the
    next task.

 * ### `applyVanillaPatches`:
 
    This is the patching process that applies patches onto Vanilla and transforms it from Vanilla to CraftBukkit. This is simply a step in
    the Spigot build process faithfully recreated in PaperGradle.

 * ### `applyBukkitPatches` / `applyCraftBukkitPatches`:
 
    Again, this is the patching process which applies patches onto Bukkit and CraftBukkit and transforms it from Bukkit and CraftBukkit to
    Spigot API and Spigot Server respectively. This is a step in the Spigot build process recreated in PaperGradle.

 * ### `buildSpigot`:
 
    As the name implies, this task is responsible for building Spigot. Up to this point, we have followed Spigot's build process exactly, so
    everything should patch fine and build correctly based on the Spigot patches. After this task is where things get a little more
    interesting.
    
 * ### `cleanSpigotJar`:
 
    This task removes the parts of the now-built Spigot jar we don't need. It really only leaves the relevant packages that we want to
    decompile.
    
    It also has another function, which is to remove bad output classes from the `buildSpigot` task. For whatever reason - probably a
    product of how Spigot depends on the remapped Minecraft server jar in the build process - the Spigot build occasionally emits duplicate
    classes where one is Notch mappings, and the other is Spigot mappings. This causes the decompile task to output some really wacky code
    when these invalid classes which are simply incorrectly mapped duplicates of other classes show up. As an easy solution, this task also
    reads in the `mcp/remove-list.txt` file and removes any of the listed file paths in that file from the jar.

 * ### `preMapReMap`:
 
    This task takes in the SRG file defined in `mcp/paper.srg` and applies the  transformations in that SRG file before the
    `deobfuscateSpigotJar` task. This task fixes two special types of problems in the decompile process:
    
      1. Classes compiled strangely for some reason. I really don't know why or how this happens, but a couple anonymous classes compile
         to their Java names with a `1` prepended to it. This is valid in bytecode, but not valid in Java, so after the decompile process
         lots of patching would be required to fix this if it wasn't fixed in this task.
      
      2. Forge's toolchain is smarter than Spigot's. One nice feature of ForgeGradle is it properly handles decompilation of implementations of
         interfaces, even if the implementation has been obfuscated. What this means is, Spigot's tooling will decompile implementation
         methods faithful to how they are in the bytecode (usually with just an `a` for a name), but Forge's will be a bit
         smarter and will decompile and patch the method with the correct name to implement the interface correctly. This removes the need to patch in
         decompilation fixes for this particular problem late in the build process.
         
         The issue is with how Spigot fixes this issue with their patches. Spigot adds the correctly named method into the class and simply
         calls the original method (again, usually named `a`) from that method. So when FernFlower decompiles this, it finds two
         methods with the exact same signature, and exact same name. FernFlower gives up when this happens and simply output empty methods.
         This could be fixed by patching in all the fixes, but ideally we would like it to simply decompile correctly the first time without
         requiring patches. We do this by remapping the Spigot methods to some arbitrary name instead - which is fine, this code won't ever
         get called. The Spigot methods are simply added to fix the issue with the Spigot toolchain which isn't present in ForgeGradle.
         
         In an attempt at following a pattern, I opted to prepend each Spigot method name that did this with the string `__clashing_` so it
         should be pretty clear why that method was renamed and what task was responsible for it. Obviously this task could take any
         arbitrary SRG file for any reason and happily apply any mappings given, so other use cases could theoretically pop up, but these
         are the two use cases which prompted this task to be created.
 
 * ### `deobfuscateSpigotJar`:
 
    This task does the magic to convert all the Spigot code to SRG (and eventually MCP) mappings. It takes in the SRG files generated from
    the `genSpigotSrgs` and outputs a deobfuscated jar. This is an automated task based on the outputs of another automated task, so not
    much fiddling should need ot happen here when upgrading Spigot or the Minecraft version, with one exception.
    
    This task also takes in the access transformer file defined in `mcp/paper_at.cfg`, where we can apply whichever access transformers we
    want for whatever reason. Typically this can be to make a package-private member public (since in NMS all code is in one package, Spigot
    likes to add members that are package-private, which doesn't work in MCP where there are actually packages) or just a general use case
    to open up a member without needed to clutter up the workspace with patches.

 * ### `sourceProcessJar`:
 
    This task does several things to the source code which makes it nicer to work with. First, it applies any MCP patch which might still
    work on our code base. Since we need to have the whole MCP code base in our project compilable, we'll take any MCP patch we can to help
    fix the build errors (usually caused by generics). Many patches will fail, since Spigot or CraftBukkit has modified the class in some
    way, but many will also succeed. ForgeGradle fails if any patch fails, but we happily take it in stride and just take the successes
    when they come. We expect failures to happen and deal with them in our own patches.
    
    Some other nice things this task does is fixes imports for classes in the same package the class is in, stripping deprecation comments,
    lots of general code cleanup, such as closing some unnecessary vertical whitespace, converting random unicode characters in the code
    back to integers, and fixing lots of floating point numbers back to the constants or expressions they represent. You can see some of the
    things this fixes in [McpCleanup.java](https://github.com/PaperMC/PaperGradle/blob/master/src/main/java/net/minecraftforge/gradle/util/mcp/McpCleanup.java).
    This is one of the great reasons for forking ForgeGradle, since we get awesome stuff like this for free. The last thing this task does
    is reformat the source code to how we like it (K&R style).

 * ### `remapSpigotJar`:
 
    This task remaps the SRG field, method, and parameter names to their MCP names. Since all SRG names are unique this is actually a
    pretty simple task. This is finally where the changes made in the `mcpRewrites` task are applied.

 * ### `applySpigotApiPatches` / `applySpigotServerPatches`:
 
    This task finally applies the MCP-mapped patches which finally brings everything from simply a remapped Spigot to a fully MCP mapped
    Paper codebase. This is pretty much a direct port (but in Java) of our old script system.

How to deal with decompile issues
---------------------------------

Typically we want to leave patches to only be the changes to the project, rather than taking up space to fix decopmile issues, so the more
decopmile issues we can fix without patches the better. Because of this, patches are usually the last resort when it comes to dealing with
decompile issues, and here's some rules to follow when trying to work out how to fix particular issues. After any of these changes are made,
`./gradlew setup` will need to be run again for these changes to be reflected back onto the source code.

 * There's duplicate classes in the codebase, some are remapped properly, but the others aren't.
 
   This is the easiest case, simply added the offending class files to the `mcp/remove-list.txt` file. Note that the remove process happens
   immediately after the Spigot build, so you need to define the files to be removed with that in mind (that is, the deobfuscate task hasn't
   happened yet).
 
 * A field or method on a class needs to have a higher visibility.
 
   This could be fixed with a patch, but to reduce the number of changes in the patches, it might make more sense to define an access
   transformer entry instead. These are listed in the `mcp/paper_at.cfg` file. Notice the access transformers are applied immediately after
   the deobfuscate task, and before the remap task, so access transformer entries need to be defined with the SRG mappings. I recommend
   using the MCPBot_Rebort IRC bot in esper for this. Non-MCP members (such as members added by Spigot) should just be defined with their
   normal name, since they have no SRG counterparts.
 
 * A field, method, or parameter in the MCP code has a name which conflicts with a variable name Spigot has added.
 
   Add an entry to `mcp/mcp-rewrites.txt` to change the dev-environment name of the MCP field, method, or parameter. You need to define the
   SRG name of the member or parameter and the new name that should be used in the MCP environment. Typically I liked to take the existing
   name and prepend `mcp` to it, but just do whatever makes sense.
   
 * A helper method defined in Spigot clashes with an already existing method, causing neither method to decompile at all.
 
   Remap the method added by Spigot using `mcp/paper.srg`, I typically prepend the method name with `__clashing_`, but of course that's
   optional.
   
 * A class has for whatever reason compiled down to an invalid name in Java causing compilation issues.
 
   Remap the class back to its proper name using `mcp/paper.srg`.
   
FAQ
---

 * _This seems like a lot of work for nothing, is all of this worth it?_
 
   Probably not.
   
 * _Wouldn't it be easier is Spigot was just based on MCP to begin with?_
 
   Yes, but we don't control Spigot, so we make do with what we have to work with.
   
 * _How hard would it be for Spigot to rebase onto MCP?_
 
   Very easy. None of this difficulty would be necessary if Spigot was based on MCP from the beginning.
   
 * _So why isn't Spigot based on MCP then?_
 
   That's not up to us. 
   
 * _Won't this break plugins?_
 
   No, plugins which use the Bukkit API are totally unaffected by any of these changes.
   
 * _Sure, okay, but what about NMS plugins?_
 
   Calls to NMS from plugins will be remapped at runtime (including reflection) so from the plugin's perspective, nothing will change, even
   though it will be interacting with SRG mapped code.
   
 * _Won't that break everything?_
 
   Not if we do it right.
   
 * _But why Gradle?!? Gradle is evil!_
 
   Some of us think Maven is evil. No, but seriously, it only made sense to use ForgeGradle as a base for this. As I stated above, we get
   a lot of things for free by simply re-using the ForgeGradle code base. The actual build system we use doesn't really matter to us.
