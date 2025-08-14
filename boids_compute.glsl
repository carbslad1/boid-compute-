// Boids Compute Shader for LÖVE 12.0
// This runs MUCH faster than fragment shader approach

#pragma language glsl4

// Compute shader entry point for LÖVE 12.0
#ifdef COMPUTE
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Boid data structure
struct Boid {
    vec2 position;
    vec2 velocity;
    float radius;
    float mass;
    float fraction;
    float hp;
};

// Storage buffers for boid data
layout(std430, binding = 0) buffer BoidBuffer {
    Boid boids[];
} boidBuffer;

// Uniform parameters
uniform int boidCount;
uniform float dt;
uniform vec2 worldSize;
uniform float sight;
uniform float ruleCohesion;
uniform float ruleAlignment;
uniform float ruleSeparation;
uniform float limitVelocity;

// Shared memory for local boid cache (massive performance boost!)
shared Boid localBoids[64];

void computemain() {
    uint gid = gl_GlobalInvocationID.x;
    uint lid = gl_LocalInvocationID.x;
    uint groupSize = gl_WorkGroupSize.x;
    
    if (gid >= boidCount) return;
    
    Boid myBoid = boidBuffer.boids[gid];
    
    // Load boids into shared memory for this work group
    uint groupStart = gl_WorkGroupID.x * groupSize;
    if (groupStart + lid < boidCount) {
        localBoids[lid] = boidBuffer.boids[groupStart + lid];
    }
    barrier();
    
    // Boids algorithm
    vec2 vecSeparation = vec2(0.0);
    vec2 vecCohesion = vec2(0.0);
    vec2 vecAlignment = vec2(0.0);
    float countCohesion = 0.0;
    float countAlignment = 0.0;
    
    // Check all boids (using shared memory for work group boids)
    for (uint i = 0; i < boidCount; i++) {
        if (i == gid) continue;
        
        Boid other;
        
        // Use shared memory if possible (much faster!)
        if (i >= groupStart && i < groupStart + groupSize && i - groupStart < 64) {
            other = localBoids[i - groupStart];
        } else {
            other = boidBuffer.boids[i];
        }
        
        vec2 diff = other.position - myBoid.position;
        float dist = length(diff);
        
        if (dist > 0.0 && dist < sight) {
            // Separation (all nearby objects)
            if (dist < sight * 0.5) {
                float force = pow(max(0.0, (sight * 0.5 - dist) / (sight * 0.5)), 3.0);
                vecSeparation -= normalize(diff) * force;
            }
            
            // Cohesion & Alignment (same fraction only)
            if (other.fraction == myBoid.fraction) {
                vecCohesion += diff;
                vecAlignment += other.velocity;
                countCohesion++;
                countAlignment++;
            }
        }
    }
    
    // Apply rules
    myBoid.velocity += vecSeparation * ruleSeparation * dt;
    
    if (countCohesion > 0.0) {
        vecCohesion /= countCohesion;
        myBoid.velocity += vecCohesion * ruleCohesion * dt;
    }
    
    if (countAlignment > 0.0) {
        vecAlignment /= countAlignment;
        myBoid.velocity += vecAlignment * ruleAlignment * dt;
    }
    
    // Limit velocity
    float speed = length(myBoid.velocity);
    if (speed > limitVelocity) {
        myBoid.velocity = myBoid.velocity * (limitVelocity / speed);
    }
    
    // Update position
    myBoid.position += myBoid.velocity * dt;
    
    // World boundaries
    if (myBoid.position.x < myBoid.radius || myBoid.position.x > worldSize.x - myBoid.radius) {
        myBoid.velocity.x *= -0.9;
        myBoid.position.x = clamp(myBoid.position.x, myBoid.radius, worldSize.x - myBoid.radius);
    }
    if (myBoid.position.y < myBoid.radius || myBoid.position.y > worldSize.y - myBoid.radius) {
        myBoid.velocity.y *= -0.9;
        myBoid.position.y = clamp(myBoid.position.y, myBoid.radius, worldSize.y - myBoid.radius);
    }
    
    // Write back to buffer
    boidBuffer.boids[gid] = myBoid;
}
#endif
