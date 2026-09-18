# Plan-mode NAT: investigates with read-only tools and presents a plan
# for approval. Write tools are not registered at all, so nothing can
# execute no matter what the model outputs — enforcement by construction,
# not by prompt. Flip a chat to build mode to run the plan.
class NatPlanAgent < NatAgent
  instructions do
    NatAgent::BASE_INSTRUCTIONS + <<~TEXT

      You are in PLAN mode. Investigate with your read tools, then present
      a short numbered plan of what you would do and end by asking the user
      to approve it (they approve by switching to Build mode). Never claim
      to have executed, created, changed, or deleted anything — report only
      what you found.
    TEXT
  end

  tools { NatAgent::READ_TOOLS }
end
