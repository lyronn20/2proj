extends Node2D

var employes: Array = []

func add_employe(pnj):
	if not employes.has(pnj):
		employes.append(pnj)
		pnj.metier = "bucheron"
		pnj.lieu_travail = self
