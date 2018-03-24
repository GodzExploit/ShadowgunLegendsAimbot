/*
Shadowgun: Legends v0.4.2 aimbot source code.
Made by shmoo.
Function naming conventions:
    ClassName_FunctionName(arguments)
...for easy reference in the included dump.
*/
 
#import "Macros.h"
#import "Config.h"
#import <substrate.h>
#import <mach-o/dyld.h>

uint64_t getRealOffset(uint64_t);

struct me_t {
	void *object;
	Vector3 location;
};

struct enemy_t {
	void *object;
	Vector3 location;
	float distanceFromMe;
	float health;
};

me_t *me;
enemy_t *currentTarget;

Quaternion lookRotation;

void *(*Component_GetTransform)(void *component) = (void *(*)(void *))getRealOffset(0x100E6CBB4);
void (*Transform_INTERNAL_GetPosition)(void *transform, Vector3 *vec) = (void (*)(void *, Vector3 *))getRealOffset(0x100ECE7E4);

void *(*ComponentPlayer_GetOwner)(void *componentPlayer) = (void *(*)(void *))getRealOffset(0x1001CB318);

void (*ComponentPlayer_LateUpdate)(void *componentPlayer);

void _ComponentPlayer_LateUpdate(void *componentPlayer){
	if(!me){
		me = new me_t();
	}
	else{
		me->object = componentPlayer;

		void *myTransform = Component_GetTransform(me->object);
		Vector3 myLocation;

		Transform_INTERNAL_GetPosition(myTransform, &myLocation);

		me->location = myLocation;
	}

	ComponentPlayer_LateUpdate(componentPlayer);
}

float (*ComponentEnemy_GetCurrentHealth)(void *componentEnemy) = (float (*)(void *))getRealOffset(0x1001F3FA4);

void (*ComponentEnemy_Update)(void *componentEnemy);

void _ComponentEnemy_Update(void *componentEnemy){
	if(!currentTarget){
		currentTarget = new enemy_t();
	}
	//we need to have a non-null me object in order to get my location
	else if(me && currentTarget){
		//before we go out to find a potential target, make sure that potential target meets these conditions
		//first, get health to check if this potential target is dead
		float firstTargetHealth = -1.0f;
		bool dead = false;

		firstTargetHealth = ComponentEnemy_GetCurrentHealth(componentEnemy);

		dead = firstTargetHealth < 1;

		//first time initialization of currentTarget's object, so assign it to whoever we find first
		if(!currentTarget->object && !dead){
			currentTarget->object = componentEnemy;
			currentTarget->health = firstTargetHealth;

			void *enemyTransform = Component_GetTransform(componentEnemy);
			Vector3 enemyLocation;

			Transform_INTERNAL_GetPosition(enemyTransform, &enemyLocation);

			currentTarget->location = enemyLocation;
			currentTarget->distanceFromMe = Vector3::distance(currentTarget->location, me->location);

			ComponentEnemy_Update(componentEnemy);

			return;
		}

		//update componentEnemy values in currentTarget
		if(currentTarget->object == componentEnemy){
			void *enemyTransform = Component_GetTransform(componentEnemy);
			Vector3 enemyLocation;

			Transform_INTERNAL_GetPosition(enemyTransform, &enemyLocation);

			currentTarget->location = enemyLocation;
			currentTarget->distanceFromMe = Vector3::distance(currentTarget->location, me->location);
			currentTarget->health = ComponentEnemy_GetCurrentHealth(currentTarget->object);;
		}

		//do not track a dead enemy
		if(currentTarget->health < 1){
			//set the currentTarget to NULL to start a new search right away
			currentTarget = NULL;

			ComponentEnemy_Update(componentEnemy);

			return;
		}

        	//try and find another target
		float potentialTargetHealth = ComponentEnemy_GetCurrentHealth(componentEnemy);

		void *potentialEnemyTransform = Component_GetTransform(componentEnemy);
		Vector3 potentialEnemyLocation;

		Transform_INTERNAL_GetPosition(potentialEnemyTransform, &potentialEnemyLocation);

		float potentialEnemyDistanceFromMe = Vector3::distance(potentialEnemyLocation, me->location);

		//we found someone closer, update currentTarget
		if(potentialTargetHealth > 1 && potentialEnemyDistanceFromMe < currentTarget->distanceFromMe){
			currentTarget->object = componentEnemy;
			currentTarget->location = potentialEnemyLocation;
			currentTarget->distanceFromMe = potentialEnemyDistanceFromMe;
			currentTarget->health = potentialTargetHealth;
		}

		//make the Quaternion that will hold a rotation to currentTarget
		lookRotation = Quaternion::LookRotation(currentTarget->location - me->location, Vector3(0, 1, 0));

		//now, do some climbing to get the object we need to modify our rotation!
		void *myOwner = ComponentPlayer_GetOwner(me->object);

		if(myOwner){
			void *blackboard = *(void **)((uint64_t)myOwner + 0x180);

			if(blackboard){
				void *desiredData = *(void **)((uint64_t)blackboard + 0xc8);

				if(desiredData){
					//set my rotation to face currentTarget
					*(Quaternion *)((uint64_t)desiredData + 0x30) = lookRotation;
				}
			}
		}
	}

	ComponentEnemy_Update(componentEnemy);
}

%ctor {
    MSHookFunction((void *)getRealOffset(0x100200C10), (void *)_ComponentPlayer_LateUpdate, (void **)&ComponentPlayer_LateUpdate);
    MSHookFunction((void *)getRealOffset(0x1001F20C4), (void *)_ComponentEnemy_Update, (void **)&ComponentEnemy_Update);
}

uint64_t getRealOffset(uint64_t offset){
    return _dyld_get_image_vmaddr_slide(0)+offset;
}
