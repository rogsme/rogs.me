+++
title = "How I got Claude certified (and how you can too)"
author = ["Roger Gonzalez"]
date = 2026-07-19
lastmod = 2026-07-19T14:13:03-03:00
tags = ["programming", "claude", "certification", "ai", "career"]
draft = false
+++

{{< figure src="/claude-cert-badge.png" >}}

I'm [Claude Certified Architect - Foundations](https://www.credly.com/badges/6ff376d3-498d-4792-b90b-cc06bc863965/linked_in?t=thryci) now. Look at me.

A friend from work, Daniel, pinged me right after he started studying because he was confused and a little frustrated. He'd gone through the official docs, done a couple of practice exams, and felt like there was no connection between what he was studying and what the exam was actually testing. Fair. I felt the same way when I started. So we hopped on a call, I dumped everything I knew, and this post is basically that call cleaned up so more people can use it.

Fair warning up front: this is part study guide, part honest review. I'll tell you how to pass, but I'm also going to be honest about the parts that felt like studying for the exam rather than becoming a better engineer. Both things are true at once.


## What I studied with {#what-i-studied-with}

The exam I took is the **Claude Certified Architect - Foundations**. The single most useful resource for me was [the Claude Certification Guide](https://claudecertificationguide.com/). The lessons are very good, and everything that showed up on my exam was covered by the syllabus there. I took notes like a maniac: more than half of a physical notebook, front and back, is just Claude notes from that site. I still recommend it without hesitation, because I genuinely learned a lot from it, not just enough to pass.

{{< img class="beach" src="/claude-cert-notes.jpg" caption="My notebook. Yikes." >}}

The thing I liked most about it is that it teaches you to _recognize_ the pitfalls the exam throws at you, without spoon-feeding you exactly what they are. So instead of memorizing "the answer is X," you build the instinct to spot what's going on. My friend from work, Reed, described this as "instinct training," which nails it. I prefer that. It stuck better.

One warning: don't over-index on practice exams. I did five or ten before the real thing, and the free mock exams floating around out there are way too basic compared to what you'll actually face. The guide's questions are the closest I found, and even those I wouldn't call identical to the real exam. Daniel was studying with a different mock exam site and the questions were so convoluted and samey that he said he fell asleep halfway through. So calibrate your expectations: use the mocks to get familiar with the format, not to predict the exact questions.


## Study Claude CLI. Seriously. Study it. {#study-claude-cli-dot-seriously-dot-study-it-dot}

This was the hardest part of the exam by far, and the part I was least prepared for.

I genuinely did not think they were going to ask about specific flags. The Claude CLI has something like a thousand of them, and my attitude going in was "I'm not learning all of this, if I need a flag I'll just run `claude --help`." In the real world, that's exactly what you do. Why would you memorize flags you can look up in two seconds? Daniel made this same point on our call, and honestly I agree with him.

But the exam doesn't care about that argument. They started asking about specific flags and what they do, and I sat there thinking _I messed up_.

So here's my advice: study the flags. You don't need to memorize all thousand of them, but go through the ones on the certification course and at least read each one and understand what it means. Not just `claude -p`. All of them. If you do one thing differently from how I studied, make it this.


## Read the questions. Then read them again. {#read-the-questions-dot-then-read-them-again-dot}

The exam is 60 questions, and you get 2 and a half hours. That's more than enough time. I finished the whole thing in about an hour and a half, went back through everything, and still submitted with time to spare. So don't rush.

But do read carefully, because the questions are _convoluted_. Sometimes it feels like they're testing whether you can read a wall of text, parse it, and pick the best answer, more than whether you know the material. English isn't my first language, and after about 45 minutes of dense, twisty questions I was toast. Budget your brain, not just your time.

A few tactics that worked for me:

-   **Read the full question before you even look at the answers.** Give it 30 to 45 seconds. If it's obviously straightforward, great, move on. If it's not, you'll be glad you understood the setup before the answers tried to trick you.
-   **Don't get stuck.** If you've spent two or three minutes on one question, pick something, flag it, and move on. You can always come back.
-   **Use the "flag for review" feature.** Before you submit, the exam shows you a list of everything you answered plus everything you flagged. I went back through all my flagged ones, re-read them, and changed a couple of answers. Then, with 30 minutes left, I went through the _entire_ exam one more time reading each prompt and my answer. Was that overkill? Probably. Did it work? Also yes. I'm thorough like that.


## The "pick the most correct answer" trap {#the-pick-the-most-correct-answer-trap}

This is the thing that trips everyone up, so it gets its own section.

A lot of questions have two answers that both technically work. The exam wants you to pick the one that's _most_ correct, and "most correct" almost always means "the most Claude-native way of doing it."

Concrete example from the kind of question you'll see: you've got a process that runs sequentially and takes too long, and you need to cut the latency. One option is to implement a message queue to parallelize the slow tasks. Another is to spawn additional agents so the work gets split up. Both reduce latency. Both are reasonable. But Claude doesn't have a message queue, and the exam heavily favors two ideas: use Claude for everything, and let the agent take control. The parallel-agents answer wins because Claude decides how many agents to spawn, and if one fails it can respawn it. The queue answer works in real life, but it's not the answer the exam is looking for.

So when two answers both work, ask yourself: which one leans hardest into letting Claude do the thing? That's usually the "most correct" one.

One important caveat, which Reed pointed out after taking the exam: this is a tie-breaker, not an absolute rule. He remembers questions testing when _not_ to use Claude too. Read the constraints first, and don't blindly pick Claude if the scenario suggests it isn't appropriate. "Let Claude do it" only helps when the remaining answers are otherwise equally sound.


## The exam-day logistics nobody warns you about {#the-exam-day-logistics-nobody-warns-you-about}

The exam costs 125 USD, it's fully proctored, and the proctoring is _strict_. Here's what actually happens so you're not caught off guard:

-   You install an app called **OnVue** on your machine. (I already uninstalled it. No shade, I just didn't need it hanging around.)
-   Before the exam, you submit photos of your environment. Then a proctor called me to take _additional_ photos. I waited around 10 minutes for the proctor to show up, so be patient.
-   Follow the instructions to the letter. They are extremely strict. I had a random piece of paper sitting on my desk and they made me throw it away. Clear your whole desk before you check in.
-   Be ready to join right at your "check-in" time so the proctor can get to you on schedule.

None of this is hard, it's just a lot of process, and it's easier when you know it's coming.


## So... is it actually worth it? {#so-dot-dot-dot-is-it-actually-worth-it}

Here's the honest part, because Daniel asked me this directly and I don't want to pretend.

Did I learn to take an exam, or did I learn something real? My honest answer is about 50/50. A chunk of the studying was pure exam-prep: memorizing flags I'd normally just look up, learning to spot which answer the test wants. That part I won't oversell.

But the other half genuinely changed how I work. I picked up new things while studying and actually changed parts of my workflow afterward. So it's not _just_ a piece of paper. There's real signal in there if you go in wanting to learn and not just wanting to pass.

Would I tell you to get certified? If your company is paying, or you've got the time and 125 bucks to spare, yeah, go for it. You'll come out a bit sharper and you get a shiny badge for LinkedIn. Just go in with clear eyes about which parts are learning and which parts are hoop-jumping.

Thanks to Daniel and Reed for their contributions to this post!

Good luck. If you're studying for this and you get stuck, my inbox is open.

See you in the next one!
