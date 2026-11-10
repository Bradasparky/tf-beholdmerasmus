#if defined _beholdmerasmus_included_
  #endinput
#endif
#define _beholdmerasmus_included_

#define LIB_BEHOLDMERASMUS "beholdmerasmus"

/**
 * Turns a client into Merasmus.
 *
 * @param iClient			Index of the client.
 * @param iHealth			The client's health, leave as 0 or below to use the convar health value.
 * @return Whether the client was turned into Merasmus.
 */
native bool BeholdMerasmus_Create(int iClient, int iHealth = 0);

/**
 * Removes the Merasmus transformation from a client.
 *
 * @param iClient			Index of the client.
 * @return Whether the client was Merasmus.
 */
native bool BeholdMerasmus_Remove(int iClient);

/**
 * Whether the client is Merasmus.
 */
native bool BeholdMerasmus_IsBoss(int iClient);

/**
 * Whether the client is performing the Hellfire attack.
 */
native bool BeholdMerasmus_IsPerformingHellfire(int iClient);

/**
 * Whether the client is performing the AoE attack.
 */
native bool BeholdMerasmus_IsPerformingAoE(int iClient);

public SharedPlugin __pl_beholdmerasmus = 
{
	name = LIB_BEHOLDMERASMUS,
	file = LIB_BEHOLDMERASMUS ... ".smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_beholdmerasmus_SetNTVOptional()
{
	MarkNativeAsOptional("BeholdMerasmus_Create");
	MarkNativeAsOptional("BeholdMerasmus_Remove");
	MarkNativeAsOptional("BeholdMerasmus_IsBoss");
	MarkNativeAsOptional("BeholdMerasmus_IsPerformingHellfire");
	MarkNativeAsOptional("BeholdMerasmus_IsPerformingAoE");
}
#endif