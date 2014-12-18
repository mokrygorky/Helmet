package rj.helmet;

import h2d.col.Bounds;
import h2d.Tile;
import hxd.Res;
import rj.helmet.dat.GameData;
import rj.helmet.Entity.EntityType;
import rj.helmet.entities.PlayerActor;
import rj.helmet.fx.ShakeEntityFx;

/**
 * ...
 * @author roguedjack
 */
class MonsterGenerator extends Entity {
	
	public var monsterClass(default, null):Class<Monster>;
	public var spawnCooldown(default, default):Float;
	public var particleGenerator(default, default):ParticleGenerator;
	var timer:Float;
	var aggroRange:Float;
	var score:Int;
	var maxHitPoints:Int;
	var hitPoints:Int;
	var tiles:Array<Tile>;
	var tmpSpawningPos:Array<{tx:Int, ty:Int}>;	

	/**
	 * 
	 * @param	monsterClass constructor must be parameterless.
	 * @param	tiles image for each hit point level, from higher to lower hitpoints.
	 * @param	hitPoints
	 * @param 	particleGenerator spawn particles when hit or destroyed -- can be null
	 * @param	data
	 */
	public function new(monsterClass:Class<Monster>, particleGenerator:ParticleGenerator, data) {
		super(EntityType.MONSTER_GENERATOR);
		this.monsterClass = monsterClass;
		this.spawnCooldown = data.time;
		this.aggroRange = data.aggroRange;
		this.score = data.score;
		this.maxHitPoints = data.hits;
		this.hitPoints = data.hits;
		this.tiles = GameData.parseEntityFrames(data.gfx);
		this.particleGenerator = particleGenerator;
		canCollide  = true;
		hardCollision = true;
		setCollisionBox(data.colbox[0], data.colbox[1], data.colbox[2], data.colbox[3]);		
		refreshImage();
		tmpSpawningPos = new Array<{tx:Int,ty:Int}>();
	}
	
	function refreshImage() {
		var hitLevel = (maxHitPoints - hitPoints) / maxHitPoints;
		var hitImage = Math.floor(hitLevel * tiles.length);		
		setImage(tiles[hitImage]);
	}
	
	override public function spawn(x:Float, y:Float) {
		super.spawn(x, y);
		timer = 0;
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		
		timer += elapsed;
		if (timer >= spawnCooldown && distanceToPlayer() <= aggroRange) {
			trySpawningMonster();
			timer -= spawnCooldown;  // cooldown even if could not spawning
		}
	}
	
	inline function distanceToPlayer():Float {
		var toPlayer = { dx:Math.round(world.player.pos.x - pos.x), dy:Math.round(world.player.pos.y - pos.y) };
		return Math.sqrt(toPlayer.dx * toPlayer.dx + toPlayer.dy * toPlayer.dy);
	}
	
	function trySpawningMonster():Bool {
		// find all adjacent free tiles.
		var t = world.toTilePos(pos.x, pos.y);		
		var nbSpawnPos = 0;
		for (tx in t.tx - 1...t.tx + 2) {						
			for (ty in t.ty - 1...t.ty + 2) {				
				if (tx == t.tx && ty == t.ty) {
					continue;
				}
				if (canSpawnAt(tx, ty)) {
					tmpSpawningPos[nbSpawnPos++] = { tx:tx, ty:ty };
				}
			}
		}
		if (nbSpawnPos == 0) {
			return false;
		}
		// spawn a monster in one of them.		
		var i = Std.random(nbSpawnPos);
		spawnMonster(tmpSpawningPos[i].tx * Main.TILE_SIZE, tmpSpawningPos[i].ty * Main.TILE_SIZE);
		return true;
	}
	
	inline function canSpawnAt(tx:Int, ty:Int):Bool {
		if (world.isBlockingAt(tx, ty)) {
			return false;
		}
		return world.isFreeForSpawning(Bounds.fromValues(tx * Main.TILE_SIZE,  ty * Main.TILE_SIZE, Main.TILE_SIZE, Main.TILE_SIZE));
	}
	
	function spawnMonster(x:Float, y:Float) {
		var m:Monster = Type.createInstance(monsterClass, []);
		world.spawnEntity(m, x, y);
	}

	public function takeHit(source:Entity, damage:Int) {
		spawnDebris();		
		
		if (hitPoints > 0) {
			if ((hitPoints -= damage) <= 0) {
				playSfx(Res.sfx.monster_die);
				spawnDebris(); // spawn x2 debris when destroyed
				remove();
				// score points if killed by player
				if (source.type == EntityType.PLAYER) {
					cast(source, PlayerActor).scorePoints(score);
				} else if (source.type == EntityType.PROJECTILE) {
					var proj = cast(source, Projectile);
					if (proj.owner != null && proj.owner.type == EntityType.PLAYER) {
						cast(proj.owner, PlayerActor).scorePoints(score);
					}
				}				
			} else {
				playSfx(Res.sfx.monster_hit_wav);
				startFx(new ShakeEntityFx());
				refreshImage();
			}
		}
	}
	
	function spawnDebris() {
		if (particleGenerator == null) {
			return;
		}
		particleGenerator.emitBatch(bounds);
	}
}