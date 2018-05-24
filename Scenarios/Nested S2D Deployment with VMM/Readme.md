<!-- TOC -->

- [Nested S2D Deployment with VMM](#Nested-S2D-Deployment-With-VMM)
    - [About the lab](#about-the-lab)
    - [Prerequisites](#prerequisites)
    - [Running the Script](#Running-the-Script)
    - [Result](#Result)
    - [Issues](#Issues)

<!-- /TOC -->

# Neste S2D Deployment with VMM

## About the lab

In this lab i have create a script to rapidly deploy new versions of Windows Server 2016 or 2019 RS5. It requires that you have some knowledge on how to create a template from a vhdx file that was created from an ISO. It will require you to have a configured VMM with VMnetworks, classifications and so on.Update the Deploy script with your settings in the intial config before the VMM deployment starts. All steps are done with PowerShell to demonstrate automation and also to demonstrate, how easy is maintaining documentation if all is done with PowerShell.

The lab will be updated once a new version of VMM is out that supports full VMM deployment including adding the nodes to VMM, as RS5 pr today is not supported on VMM 1801.

## Prerequisites

VMM Installed and a base knowledge of how the WSLab works.
Hyper-V cluster, can be regular cluster or S2D

## Running the Script

You can run the script 2 ways. As one big script or in steps. I do recomend to run it in steps the first time.

## Result

The result will be a fully functional S2D cluster with 1 virtualdisk pr node you deploy with 40GB usable diskspace. You will be able to test new features, like Dedupe, if you deploy more Clusters you can setup Cluster Sets.

## Issues

The latest version of Insider Build is having an issue with creating a cluster remotly.